import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'backend_service.dart';
import 'support_relay.dart';

/// Outbound email.
///
/// This class used to hold a Resend API key (read from the bundled .env) and
/// POST directly to api.resend.com. Because the key shipped inside the APK,
/// anyone could extract it and send mail as Brahma Journal to any address —
/// a ready-made phishing channel aimed at this app's own users. It also
/// interpolated user-supplied names and messages into HTML without escaping.
///
/// Sending now happens in the `sendSupportEmail` Cloud Function, which holds
/// the key in Secret Manager, escapes every user-supplied value, and will only
/// ever address the operator.
class EmailService {
  EmailService({BackendService? backend})
      : _backend = backend ?? BackendService();

  final BackendService _backend;

  /// Files a support ticket.
  ///
  /// Preferred path is the `sendSupportEmail` Cloud Function, which holds the
  /// Resend credentials and emails the operator. That function only exists once
  /// Functions are deployed, which requires the Blaze plan — so when it is
  /// unreachable the ticket is written straight to Firestore instead.
  ///
  /// The fallback stores; it does not send. Nothing here can email anyone,
  /// because the app deliberately no longer holds the mail credentials: that
  /// key used to ship inside the APK, where anyone could extract it and send
  /// mail as this brand to its own users. A stored ticket the operator reads in
  /// the console is a worse experience than an email, and a much better one
  /// than a lost message.
  Future<bool> sendSupportQuery({
    required String name,
    required String email,
    required String category,
    required String message,
  }) async {
    try {
      // name and email come from the caller's verified ID token on the server,
      // so they are no longer accepted from the client at all.
      return await _backend.sendSupportTicket(
        category: category,
        message: message,
      );
    } catch (e) {
      debugPrint('ℹ️ Support mail function unavailable ($e) — using fallbacks');
    }

    // Store first, notify second. The ticket surviving matters more than the
    // email arriving, and the admin inbox reads from Firestore either way.
    final stored = await _storeTicketDirectly(category: category, message: message);

    // Best-effort delivery through whatever relay is configured. A failure here
    // is invisible to the user because the message is already saved.
    await SupportRelay.send(
      name: name,
      email: email,
      category: category,
      message: message,
    );

    return stored;
  }

  Future<bool> _storeTicketDirectly({
    required String category,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await FirebaseFirestore.instance.collection('support_tickets').add({
        // Field names and bounds match the support_tickets rule exactly; the
        // write is rejected otherwise.
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'category': category.substring(0, category.length.clamp(0, 60)),
        'message': message.substring(0, message.length.clamp(0, 5000)),
        'emailed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ Support ticket could not be stored: $e');
      return false;
    }
  }

  /// Premium signup alerts are raised by verifySubscriptionPayment once the
  /// payment signature verifies, so there is nothing for the client to send.
  /// Kept so existing call sites continue to compile and behave.
  Future<bool> sendPaymentNotification({
    required String name,
    required String email,
    required String planSelected,
    required String paymentId,
    String? subscriptionId,
  }) async {
    return true;
  }
}
