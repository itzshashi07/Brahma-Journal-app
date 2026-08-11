import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The client for the Node.js API, which owns all application data in MongoDB.
///
/// ─────────────────────────────────────────────────────────────────────────
/// The division of labour this class exists to enforce
///
///   • **Firebase Auth** — who the user is. Signup, login, logout, Google,
///     phone, password reset, email verification. Never touched here beyond
///     reading the ID token.
///   • **Firebase Cloud Messaging** — push delivery. See
///     FirebaseMessagingService.
///   • **This API** — everything else: journals, profiles, the board, articles,
///     the library, counselling, notification records.
///
/// The app holds no credentials of its own. Every request carries the Firebase
/// ID token in an Authorization header, the server verifies it with the Admin
/// SDK, and authorization is decided there. Nothing in the app decides what a
/// user may read — that was firestore.rules' job and it is now the API's.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Where the API lives.
  ///
  /// Production is the default, so a release build needs no flags and cannot
  /// ship pointing at somebody's laptop. Override for local work:
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
  ///
  /// 10.0.2.2 rather than localhost — that is the host machine as seen from the
  /// Android emulator, where `localhost` is the emulator itself.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://innenflow-backend.onrender.com',
  );

  final http.Client _client = http.Client();

  /// How long to wait before giving up.
  ///
  /// Two values, because the first request of a session is not like the rest.
  /// The API is on Render's free tier, which suspends the process after a spell
  /// of inactivity and cold-starts it on the next request — that takes the best
  /// part of a minute, during which the socket is open and simply quiet. A flat
  /// 20s budget turns every first launch of the morning into "could not reach
  /// the server", which is a false accusation: the server is fine, it is
  /// getting dressed.
  ///
  /// So the first request in a process gets a long budget, and once anything
  /// has come back the short one applies for the rest of the session.
  static const _timeout = Duration(seconds: 20);
  static const _coldStartTimeout = Duration(seconds: 75);

  /// Whether the server has answered anything yet this session.
  bool _warm = false;

  Duration get _budget => _warm ? _timeout : _coldStartTimeout;

  // ─────────────────────────── auth ───────────────────────────

  /// The caller's Firebase ID token.
  ///
  /// Not cached. The SDK caches it internally and refreshes it when it is
  /// within five minutes of expiry, so asking every time is cheap and gets the
  /// refresh for free. Caching it here would reintroduce the expired-token bug
  /// the SDK already solves.
  Future<String?> _idToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken();
    } catch (e) {
      debugPrint('⚠️ api: could not get ID token: $e');
      return null;
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await _idToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Wakes the server, without waiting for it.
  ///
  /// Called during boot behind the first frame. On a suspended free-tier
  /// instance the cold start runs while the user is still looking at the
  /// dashboard, so the screen that actually needs data finds the process
  /// already up. Costs one unauthenticated request and cannot fail in a way
  /// that matters — if it does not land, the next real call simply pays the
  /// cold-start budget itself.
  Future<void> warmUp() async {
    try {
      await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(_coldStartTimeout);
      _warm = true;
      debugPrint('▶ api: server warm');
    } catch (e) {
      debugPrint('⚠️ api: warm-up did not land: $e');
    }
  }

  // ─────────────────────────── verbs ───────────────────────────

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _send(() async => _client.get(uri, headers: await _headers()));
  }

  Future<dynamic> post(String path, [Object? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(() async => _client.post(
          uri,
          headers: await _headers(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  /// Replaces a resource wholesale, as against [patch]'s partial update.
  ///
  /// Used where the app owns the entire collection and sends it back intact —
  /// a member's affirmation set, for instance, where a removed line has to
  /// actually disappear rather than merge back in.
  Future<dynamic> put(String path, [Object? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(() async => _client.put(
          uri,
          headers: await _headers(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> patch(String path, [Object? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(() async => _client.patch(
          uri,
          headers: await _headers(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(() async => _client.delete(uri, headers: await _headers()));
  }

  /// Issues the request, retrying once on an expired token.
  ///
  /// The retry matters: an ID token lives an hour, the app can sit backgrounded
  /// for longer, and the first request after resuming would otherwise fail with
  /// a 401 the user sees as "something went wrong". `getIdToken(true)` forces a
  /// refresh and the second attempt succeeds. Only one retry — if a forced
  /// refresh still yields a rejected token, the session is genuinely over.
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(_budget);
    } on TimeoutException {
      throw ApiException(
        0,
        _warm
            ? 'The server took too long to respond.'
            : 'The server is waking up. Please try again in a moment.',
      );
    } catch (e) {
      throw ApiException(0, 'Could not reach the server.', cause: e);
    }

    // Something came back, so the process is up and the cold-start allowance is
    // no longer warranted for the rest of the session.
    _warm = true;

    if (response.statusCode == 401 && _isExpired(response)) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.getIdToken(true);
          response = await request().timeout(_timeout);
        } catch (_) {
          // Fall through to the error handling below with the original 401.
        }
      }
    }

    return _decode(response);
  }

  bool _isExpired(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body is Map && body['error']?['code'] == 'token_expired';
    } catch (_) {
      return false;
    }
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode == 204 || response.body.isEmpty) return null;

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      // A non-JSON body from a proxy or a crashed process. The status code is
      // the only reliable thing in it.
      if (response.statusCode >= 400) {
        throw ApiException(response.statusCode, 'Unexpected response.');
      }
      return null;
    }

    if (response.statusCode >= 400) {
      final message = body is Map
          ? (body['error']?['message'] as String? ?? 'Request failed.')
          : 'Request failed.';
      throw ApiException(response.statusCode, message);
    }

    return body;
  }
}

/// A failure the UI can show a person.
///
/// `status` 0 means the request never reached the server — a distinction worth
/// keeping, because "you are offline" and "the server said no" want different
/// wording on screen.
class ApiException implements Exception {
  final int status;
  final String message;
  final Object? cause;

  ApiException(this.status, this.message, {this.cause});

  bool get isOffline => status == 0;
  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;

  @override
  String toString() => 'ApiException($status): $message';
}
