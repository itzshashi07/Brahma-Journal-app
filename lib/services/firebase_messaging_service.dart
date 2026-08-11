import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_service.dart';
import 'notification_service.dart';

/// Push notifications, delivered by Firebase Cloud Messaging.
///
/// ─────────────────────────────────────────────────────────────────────────
/// What this replaces
///
/// Until now "push" was a Firestore `snapshots()` listener held open by the
/// running app, raising a local notification when a document arrived. That
/// worked, and it had one unavoidable limit that NotificationCenter documented
/// honestly: it fired *while the app was running*, not when it had been
/// killed. Someone who closed the app never learned that their counsellor had
/// replied.
///
/// With application data moving to MongoDB those listeners are going away
/// regardless — MongoDB has no client-side realtime channel. FCM replaces them,
/// and delivers to a terminated app, which is what the feature always needed.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Why messages are rendered locally rather than by the system
///
/// The server sends data-only messages: no `notification` block. That is
/// deliberate. A `notification` message is drawn by the OS before the app sees
/// it, and on Android in the background the app never sees it at all — which
/// would break both the unread badge (nothing to observe) and tap routing (the
/// route would not reach the handler).
///
/// So every message arrives as data and is drawn through
/// [NotificationService], on the `brahma_alerts_channel` the app already
/// declares. One rendering path for local and remote notifications instead of
/// two that drift apart.
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _local = NotificationService();
  final _api = ApiService();

  /// Emits the in-app route a notification asked for, when one is tapped.
  /// main.dart listens and pushes it onto the router.
  final _taps = StreamController<String>.broadcast();
  Stream<String> get notificationTaps => _taps.stream;

  /// Emits whenever a message lands, so NotificationCenter can re-read the
  /// unread counts without polling.
  final _messages = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get messages => _messages.stream;

  static const _kDeviceIdKey = 'fcm_device_id';

  bool _initialized = false;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<User?>? _authSub;

  String? get token => _token;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // iOS will not issue an APNs token — and therefore no FCM token — until
    // the user has granted permission. On Android 13+ this is the same
    // POST_NOTIFICATIONS prompt flutter_local_notifications already asks for;
    // asking twice is harmless because the OS only shows it once.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('▶ fcm: permission ${settings.authorizationStatus.name}');

    // Suppress the system's own banner for foreground messages on iOS. Ours is
    // drawn by flutter_local_notifications, and without this the user sees the
    // same notification twice.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromBackground);

    // A tap that launched the app from a terminated state. The message is
    // waiting here rather than on the stream, and is delivered exactly once.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _routeFor(initial);

    // The token is bound to the signed-in member, so registration follows auth
    // rather than app launch. Signing out detaches the token server-side —
    // otherwise the next person to use the handset inherits the last one's
    // counselling replies.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _registerToken();
      } else {
        await _unregisterToken();
      }
    });

    // FCM rotates tokens on reinstall, on restore to a new device, and
    // occasionally on its own. A rotation that is not reported leaves the
    // server pushing to a dead address.
    _refreshSub = _messaging.onTokenRefresh.listen((token) async {
      _token = token;
      if (FirebaseAuth.instance.currentUser != null) await _registerToken();
    });
  }

  // ─────────────────────────── registration ───────────────────────────

  /// A stable id for this install, so the server can retire this device's
  /// previous token on rotation instead of accumulating a dead row per
  /// rotation for the life of the install.
  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kDeviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = const Uuid().v4();
    await prefs.setString(_kDeviceIdKey, fresh);
    return fresh;
  }

  Future<void> _registerToken() async {
    try {
      // On iOS the APNs token can lag the FCM one immediately after launch;
      // getToken() returns null rather than throwing, and retrying on the next
      // refresh event is the documented remedy.
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ fcm: no token yet, awaiting refresh');
        return;
      }
      _token = token;

      final info = await PackageInfo.fromPlatform();
      await _api.post('/api/devices', {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : defaultTargetPlatform == TargetPlatform.android
                ? 'android'
                : 'web',
        'deviceId': await _deviceId(),
        'appVersion': '${info.version}+${info.buildNumber}',
      });
      debugPrint('▶ fcm: device registered');
    } catch (e) {
      // A failed registration costs this device its pushes until the next
      // launch retries. It must not stop the app from starting.
      debugPrint('⚠️ fcm: registration failed: $e');
    }
  }

  Future<void> _unregisterToken() async {
    final token = _token;
    if (token == null) return;
    try {
      await _api.delete('/api/devices/$token');
    } catch (e) {
      debugPrint('⚠️ fcm: unregister failed: $e');
    }
    _token = null;
  }

  // ─────────────────────────── delivery ───────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    _messages.add(message);

    final data = message.data;
    final title = data['title'] ?? message.notification?.title ?? 'InnenFlow';
    final body = data['body'] ?? message.notification?.body ?? '';
    final route = data['route'] ?? '';

    _local.showNow(
      // Keyed by subject where the server supplies one, so a busy conversation
      // replaces its own tray line instead of stacking one per reply — the
      // same behaviour NotificationCenter had with `session.id.hashCode`.
      id: (data['thoughtId'] ?? data['sessionId'] ?? data['notificationId'] ??
              message.messageId ??
              title)
          .hashCode,
      title: title,
      body: body,
      payload: route.isEmpty ? null : route,
    );
  }

  void _onOpenedFromBackground(RemoteMessage message) {
    _messages.add(message);
    _routeFor(message);
  }

  void _routeFor(RemoteMessage message) {
    final route = message.data['route'];
    if (route is String && route.isNotEmpty) _taps.add(route);
  }

  void dispose() {
    _refreshSub?.cancel();
    _authSub?.cancel();
    _taps.close();
    _messages.close();
  }
}

/// Handles a message that arrives while the app is in the background or
/// terminated.
///
/// **Must be a top-level function.** Android runs it in a separate isolate with
/// no access to anything the running app has in memory, so it cannot be a
/// method and cannot close over state. It also has to be annotated
/// `@pragma('vm:entry-point')` or tree-shaking removes it from release builds
/// and background messages silently stop working — a bug that only ever
/// reproduces in a release APK.
///
/// Firebase is re-initialised here because this isolate did not run main().
/// That is not optional and not an optimisation to skip: firebase_messaging's
/// own background machinery resolves the default app before it hands the
/// message over, so without it the plugin logs
///
///     [core/no-app] No Firebase App '[DEFAULT]' has been created
///
/// and the notification arrives with no title and no body — which is exactly
/// how this failed the first time it was tested on a real device.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Deliberately minimal beyond this. The isolate has a short budget and no UI,
  // so it draws the tray notification and leaves the unread counts to be
  // re-read when the app is next opened.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Already initialised is fine and expected on some launch paths; anything
    // else still lets the tray notification through below, because
    // flutter_local_notifications itself needs no Firebase app.
    debugPrint('ℹ️ fcm(bg): firebase init: $e');
  }

  // The lightweight initialiser, not init(): the full one subscribes to
  // FirebaseAuth and opens a Firestore listener, neither of which belongs in
  // an isolate that exists to draw one notification and exit.
  await NotificationService().initForBackground();

  final data = message.data;
  final title = data['title'] ?? message.notification?.title ?? 'InnenFlow';
  final body = data['body'] ?? message.notification?.body ?? '';
  final route = data['route'] ?? '';

  await NotificationService().showNow(
    id: (data['thoughtId'] ?? data['sessionId'] ?? data['notificationId'] ??
            message.messageId ??
            title)
        .hashCode,
    title: title,
    body: body,
    payload: route.isEmpty ? null : route,
  );

  if (kDebugMode) {
    debugPrint('▶ fcm(bg): ${jsonEncode(data)}');
  }
}
