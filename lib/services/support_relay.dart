import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'package:http/http.dart' as http;

/// Delivers a support ticket to an external mail relay.
///
/// Cloud Functions need the Blaze plan, and the app cannot hold the Resend key
/// — it ships inside the APK where anyone can read it and send mail as this
/// brand. This is the third way: a small endpoint you own, holding the
/// credential, that the app can safely call.
///
/// Configured from `app_config/support`, so the endpoint can be changed or
/// switched between providers without shipping a build:
///
/// ```
/// app_config/support {
///   enabled:  true,
///   provider: "generic" | "web3forms",
///   url:      "https://script.google.com/macros/s/AKfy.../exec",
///   accessKey: "..."            // web3forms only
/// }
/// ```
///
/// Works with Google Apps Script, Cloudflare Workers, Vercel, Netlify,
/// Web3Forms, Formspree — anything that accepts a JSON POST.
///
/// **On the endpoint being discoverable:** it is readable by signed-in members,
/// so a determined user could find and call it. That is deliberate and bounded
/// — the endpoint can only deliver a support message to the operator, so the
/// worst case is spam in one inbox. Compare that with the Resend key, which
/// would let the same person send mail as InnenFlow to every user. Add
/// rate limiting at the provider if it is ever abused.
class SupportRelay {
  static Future<Map<String, dynamic>?> _config() async {
    try {
      // Same document, now served by the Node.js API from MongoDB. A missing
      // key answers 404, which ApiService raises — caught below and treated as
      // "no relay configured", which is the truthful reading.
      final body = await ApiService().get('/api/support/config/support');
      final value = body?['value'];
      if (value is! Map) return null;
      final data = Map<String, dynamic>.from(value);
      if (data['enabled'] != true) return null;
      final url = (data['url'] as String?)?.trim();
      if (url == null || url.isEmpty) return null;
      return data;
    } catch (e) {
      debugPrint('ℹ️ Support relay config unavailable: $e');
      return null;
    }
  }

  /// Posts the ticket. Returns true only when the relay accepted it.
  ///
  /// Never throws: the caller has already stored the ticket in Firestore, so a
  /// relay failure costs the notification, not the message.
  static Future<bool> send({
    required String name,
    required String email,
    required String category,
    required String message,
  }) async {
    final config = await _config();
    if (config == null) return false;

    final url = (config['url'] as String).trim();
    final provider = (config['provider'] as String?)?.trim() ?? 'generic';

    // Web3Forms expects its own field names and an access key; everything else
    // gets a plain, predictable JSON body.
    final body = provider == 'web3forms'
        ? {
            'access_key': config['accessKey'] ?? '',
            'subject': 'InnenFlow — $category',
            'from_name': name.isEmpty ? 'Friend' : name,
            'email': email,
            'message': message,
          }
        : {
            'type': 'support_ticket',
            'name': name,
            'email': email,
            'category': category,
            'message': message,
            'sentAt': DateTime.now().toUtc().toIso8601String(),
          };

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      // Apps Script answers 302 to a redirect it then follows; treat any 2xx or
      // 3xx as delivered rather than insisting on exactly 200.
      final ok = response.statusCode >= 200 && response.statusCode < 400;
      if (!ok) {
        debugPrint('⚠️ Support relay returned ${response.statusCode}: ${response.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('⚠️ Support relay unreachable: $e');
      return false;
    }
  }
}
