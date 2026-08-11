import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';
import '../models/announcement.dart';
import 'api_service.dart';

class NotificationService {
  // Singleton instance
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ApiService _api = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Initialize notifications
  Future<void> init() async {
    if (_isInitialized) return;

    // Android Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle tapping on notification if needed
        print('Notification tapped: ${response.payload}');
      },
    );

    _isInitialized = true;

    // Request permissions for Android 13+
    await requestPermissions();
  }

  // Request permissions
  Future<void> requestPermissions() async {
    try {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      print('Error requesting notification permissions: $e');
    }
  }

  /// Where the Firestore listener used to be.
  ///
  /// A `snapshots()` subscription on /notifications stood in for push: it woke
  /// when a broadcast document arrived and raised a local notification. It had
  /// one unavoidable limit — it only fired while the app was in the foreground,
  /// so anybody who closed the app never learned anything had happened.
  ///
  /// FCM does this now, and does it to a closed app. There is deliberately no
  /// replacement listener here: keeping one would mean every device holding an
  /// open connection to be told something it is already being pushed, which is
  /// the cost this migration exists to remove.

  /// Prepares *only* the tray plugin, for use in a background isolate.
  ///
  /// [init] cannot be used there. It subscribes to `FirebaseAuth.authStateChanges`
  /// and opens a Firestore listener — both of which need a fully configured
  /// Firebase app and a running UI process, and neither of which means anything
  /// in an isolate that exists to draw one notification and exit. Calling it
  /// from the background handler is what made background pushes arrive blank:
  /// the auth call threw, [showNow]'s catch swallowed it, and nothing was drawn.
  ///
  /// This does the one thing that isolate actually needs.
  Future<void> initForBackground() async {
    if (_isInitialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // The foreground process already asked. Asking again from a background
        // isolate would be a permission prompt with no app on screen.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(settings);
    _isInitialized = true;
  }

  /// Puts a notification in the system tray right now, from data this device
  /// already has.
  ///
  /// Every remote message is drawn through here, and so is anything the app
  /// wants to raise locally — one rendering path instead of two that drift.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      try {
        await init();
      } catch (e) {
        debugPrint('⚠️ Notifications unavailable: $e');
        return;
      }
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'brahma_alerts_channel',
        'InnenFlow Alerts',
        channelDescription:
            'Notifications for blogs, community questions, and library books.',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _localNotifications.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('⚠️ Could not show notification: $e');
    }
  }

  /// Publishes a broadcast.
  ///
  /// The server writes the record and sends the push as one step, so the two
  /// cannot come apart because the app was killed between two client writes.
  /// Admin-only on the server — a broadcast now genuinely reaches every device,
  /// which is not a thing any signed-in member should be able to do.
  Future<void> sendNotification({
    required String title,
    required String body,
    required String type,
    String? route,
  }) async {
    try {
      await _api.post('/api/notifications', {
        'title': title,
        'body': body,
        'type': type,
        if (route != null) 'route': route,
      });
    } catch (e) {
      debugPrint('⚠️ Could not publish notification: $e');
    }
  }

  /// Creates an announcement and tells everyone about it.
  ///
  /// Both halves in one request. The client used to write the announcement and
  /// then write a broadcast document; doing it server-side means the pair
  /// cannot come apart if the app dies between the two.
  Future<void> createAnnouncement({
    required String title,
    required String content,
    required String authorName,
  }) async {
    await _api.post('/api/notifications/announcements', {
      'title': title,
      'content': content,
      'authorName': authorName,
    });
  }

  /// The broadcast feed, floored server-side at the member's join date so a
  /// new account does not open the app to years of announcements about
  /// articles it has never seen.
  Future<List<AppNotification>> fetchNotifications() async {
    try {
      final body = await _api.get('/api/notifications', query: {'limit': '100'});
      final list = (body?['notifications'] as List? ?? const []);
      return list
          .map((n) => AppNotification.fromJson(Map<String, dynamic>.from(n as Map)))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Notifications unavailable: $e');
      return const [];
    }
  }

  Future<List<Announcement>> fetchAnnouncements() async {
    try {
      final body = await _api.get('/api/notifications/announcements');
      final list = (body?['announcements'] as List? ?? const []);
      return list
          .map((a) => Announcement.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Announcements unavailable: $e');
      return const [];
    }
  }

  /// Single-shot streams, so existing StreamBuilder call sites compile
  /// unchanged. There is nothing live behind them any more and nothing needs
  /// to be: a notification that arrives while the screen is open arrives as a
  /// push, which is what refreshes it.
  Stream<List<AppNotification>> streamNotifications() =>
      Stream.fromFuture(fetchNotifications());

  Stream<List<Announcement>> streamAnnouncements() =>
      Stream.fromFuture(fetchAnnouncements());

  Future<void> deleteAnnouncement(String announcementId) async {
    await _api.delete('/api/notifications/announcements/$announcementId');
  }

  // Clean up
  void dispose() {
    // Nothing to tear down any more: the Firestore subscription this used to
    // cancel is gone, and FCM's lifetime is owned by the platform.
  }
}
