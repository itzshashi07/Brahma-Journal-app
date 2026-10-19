import 'dart:async';

import 'package:brahma_app/core/theme/app_theme.dart';
import 'package:brahma_app/models/announcement.dart';
import 'package:brahma_app/models/app_notification.dart';
import 'package:brahma_app/providers/auth_provider.dart';
import 'package:brahma_app/screens/notifications/notifications_screen.dart';
import 'package:brahma_app/services/notification_center.dart';
import 'package:brahma_app/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeAuth extends ChangeNotifier implements AuthProvider {
  FakeAuth({this.isAdmin = false});
  @override
  final bool isAdmin;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCenter extends ChangeNotifier implements NotificationCenter {
  @override
  Future<void> refresh() async {}
  @override
  Future<void> markAllRead() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotifications implements NotificationService {
  final removed = <String>{};
  final calls = <String>[];
  bool failLoad = false;
  bool failRemove = false;
  int loads = 0;
  final notifications = [
    AppNotification(
        id: 'one',
        title: 'A moment for yourself',
        body: 'Your next small step is waiting.',
        type: 'info',
        createdAt: DateTime(2026, 10, 5)),
    AppNotification(
        id: 'two',
        title: 'An update to keep',
        body: 'Stay kind to yourself today.',
        type: 'info',
        createdAt: DateTime(2026, 10, 5)),
  ];
  @override
  Future<List<AppNotification>> fetchNotifications() async {
    loads++;
    if (failLoad) throw Exception('offline');
    return notifications
        .where((item) => !removed.contains('broadcast:${item.id}'))
        .toList();
  }

  @override
  Future<List<Announcement>> fetchAnnouncements() async {
    if (failLoad) throw Exception('offline');
    return [
      if (!removed.contains('announcement:one'))
        Announcement(
            id: 'one',
            title: 'Community update',
            content: 'A new place to pause and share a small win.',
            authorName: 'Admin',
            createdAt: DateTime(2026, 10, 5)),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAdminAlerts() async {
    if (failLoad) throw Exception('offline');
    return [
      if (!removed.contains('admin:one'))
        {
          '_id': 'one',
          'title': 'A new support request needs review',
          'body': 'Please review this clearly labelled test request.',
          'subjectEmail': 'qa@example.com',
          'route': '/counselling',
          'createdAt': '2026-10-05T10:00:00Z'
        },
    ];
  }

  @override
  Future<void> dismissNotification(String kind, String id) async {
    calls.add('dismiss:$kind:$id');
    if (failRemove) throw Exception('offline');
    removed.add('$kind:$id');
  }

  @override
  Future<void> dismissAll(String kind) async {
    calls.add('clear:$kind');
    for (final item in notifications) {
      removed.add('$kind:${item.id}');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showInbox(WidgetTester tester, FakeNotifications service,
    {bool admin = false, Stream<Object?>? updates}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
          create: (_) => FakeAuth(isAdmin: admin)),
      ChangeNotifierProvider<NotificationCenter>(create: (_) => FakeCenter()),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: NotificationsScreen(
          service: service, updates: updates ?? const Stream.empty()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'member removal is scoped, persists on reopen, and does not reload the feed',
      (tester) async {
    final service = FakeNotifications();
    await showInbox(tester, service);
    expect(find.byTooltip('Admin options'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('remove-broadcast-one')));
    await tester.pumpAndSettle();
    expect(find.text('A moment for yourself'), findsNothing);
    expect(find.text('An update to keep'), findsOneWidget);
    expect(service.calls, ['dismiss:broadcast:one']);
    expect(service.loads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await showInbox(tester, service);
    expect(find.text('A moment for yourself'), findsNothing);
    expect(find.text('An update to keep'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('failed removal restores the card and preserves the loaded feed',
      (tester) async {
    final service = FakeNotifications()..failRemove = true;
    await showInbox(tester, service);
    await tester.tap(find.byKey(const ValueKey('remove-broadcast-one')));
    await tester.pumpAndSettle();
    expect(find.text('A moment for yourself'), findsOneWidget);
    expect(find.text('Could not remove this update. Please try again.'),
        findsOneWidget);
    expect(service.loads, 1);
    service.failRemove = false;
    await tester.tap(find.byKey(const ValueKey('remove-broadcast-one')));
    await tester.pumpAndSettle();
    expect(find.text('A moment for yourself'), findsNothing);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('offline inbox offers retry instead of claiming it is empty',
      (tester) async {
    final service = FakeNotifications()..failLoad = true;
    await showInbox(tester, service);
    expect(find.text('You’re all caught up'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    service.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('A moment for yourself'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('announcement removal does not hide a broadcast with the same id',
      (tester) async {
    final service = FakeNotifications();
    await showInbox(tester, service);
    await tester.ensureVisible(find.text('Announcements'));
    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-announcement-one')));
    await tester.pumpAndSettle();
    expect(find.text('Community update'), findsNothing);
    await tester.ensureVisible(find.text('Notifications'));
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('A moment for yourself'), findsOneWidget);
    expect(service.calls, ['dismiss:announcement:one']);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('admin alert removal only dismisses the alert for this account',
      (tester) async {
    final service = FakeNotifications();
    await showInbox(tester, service, admin: true);
    await tester.ensureVisible(find.text('Admin alerts'));
    await tester.tap(find.text('Admin alerts'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('remove-admin-one')));
    await tester.pumpAndSettle();
    expect(find.text('A new support request needs review'), findsNothing);
    expect(service.calls, ['dismiss:admin:one']);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('clear list uses account dismissal and allows later updates',
      (tester) async {
    final service = FakeNotifications();
    await showInbox(tester, service);
    await tester.tap(find.byTooltip('Clear this list'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear list'));
    await tester.pumpAndSettle();
    expect(service.calls, ['clear:broadcast']);
    expect(find.text('You’re all caught up'), findsOneWidget);
    service.notifications.add(AppNotification(
        id: 'new',
        title: 'A later update',
        body: '',
        type: 'info',
        createdAt: DateTime(2026, 10, 5)));
    await tester.pumpWidget(const SizedBox.shrink());
    await showInbox(tester, service);
    expect(find.text('A later update'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('a push refreshes the visible inbox without reopening',
      (tester) async {
    final service = FakeNotifications();
    final updates = StreamController<Object?>();
    await showInbox(tester, service, updates: updates.stream);
    service.notifications.insert(
        0,
        AppNotification(
            id: 'fresh',
            title: 'Just arrived',
            body: '',
            type: 'info',
            createdAt: DateTime(2026, 10, 5)));
    updates.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Just arrived'), findsOneWidget);
    expect(service.loads, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(updates.close());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
