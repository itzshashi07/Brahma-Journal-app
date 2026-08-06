import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';
import '../models/announcement.dart';

class NotificationService {
  // Singleton instance
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  final DateTime _initTime = DateTime.now();
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
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

    // Start/stop listening to notifications based on auth state
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _startRealtimeListener();
      } else {
        _notificationSubscription?.cancel();
        _notificationSubscription = null;
      }
    });
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

  // Start real-time Firestore listener
  void _startRealtimeListener() {
    _notificationSubscription?.cancel();
    
    // Listen to notifications collection
    _notificationSubscription = _db
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final notification = AppNotification.fromFirestore(doc);
          
          // Only show popup for notifications created AFTER the app started
          if (notification.createdAt.isAfter(_initTime.subtract(const Duration(seconds: 2)))) {
            _showLocalNotification(notification);
          }
        }
      }
    }, onError: (e) {
      print('Error in notifications listener: $e');
    });
  }

  // Display a system-level popup notification
  Future<void> _showLocalNotification(AppNotification notification) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'brahma_alerts_channel',
      'Brahma Journal Alerts',
      channelDescription: 'Notifications for blogs, community questions, and library books.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use a unique ID for each notification based on hash code or timestamp
    final notificationId = notification.id.hashCode;

    await _localNotifications.show(
      notificationId,
      notification.title,
      notification.body,
      platformDetails,
      payload: notification.route,
    );
  }

  // Write a new notification event to Firestore
  Future<void> sendNotification({
    required String title,
    required String body,
    required String type,
    String? route,
  }) async {
    try {
      final notif = AppNotification(
        id: '',
        title: title,
        body: body,
        type: type,
        route: route,
        createdAt: DateTime.now(),
      );
      // Attributed to its author so a member who abuses the broadcast feed can
      // be identified and rate-limited; firestore.rules requires the field to
      // match the caller's own uid, so it cannot be forged.
      await _db.collection('notifications').add({
        ...notif.toMap(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      print('Error sending notification to Firestore: $e');
    }
  }

  // Create an announcement and send a corresponding notification
  Future<void> createAnnouncement({
    required String title,
    required String content,
    required String authorName,
  }) async {
    try {
      // 1. Save announcement document
      final docRef = _db.collection('announcements').doc();
      final announcement = Announcement(
        id: docRef.id,
        title: title,
        content: content,
        authorName: authorName,
        createdAt: DateTime.now(),
      );
      await docRef.set(announcement.toMap());

      // 2. Trigger global notification
      await sendNotification(
        title: '📢 Admin Announcement',
        body: title,
        type: 'announcement',
        route: '/notifications',
      );
    } catch (e) {
      print('Error creating announcement: $e');
      rethrow;
    }
  }

  // Stream notification history
  Stream<List<AppNotification>> streamNotifications() {
    return _db
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList();
    });
  }

  // Stream announcement list
  Stream<List<Announcement>> streamAnnouncements() {
    return _db
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Announcement.fromFirestore(doc)).toList();
    });
  }

  // Delete an announcement
  Future<void> deleteAnnouncement(String announcementId) async {
    await _db.collection('announcements').doc(announcementId).delete();
  }

  // Clean up
  void dispose() {
    _notificationSubscription?.cancel();
  }
}
