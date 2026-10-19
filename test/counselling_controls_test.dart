import 'package:brahma_app/core/constants/counselling.dart';
import 'package:brahma_app/core/theme/app_theme.dart';
import 'package:brahma_app/models/counselling_session.dart';
import 'package:brahma_app/providers/auth_provider.dart';
import 'package:brahma_app/screens/counselling/counselling_actions.dart';
import 'package:brahma_app/screens/counselling/counselling_chat_view.dart';
import 'package:brahma_app/screens/counselling/counselling_inbox_screen.dart';
import 'package:brahma_app/screens/counselling/counselling_screen.dart';
import 'package:brahma_app/services/counselling_service.dart';
import 'package:brahma_app/services/notification_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class SupportTestAuth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isAdmin => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SupportTestNotifications extends ChangeNotifier
    implements NotificationCenter {
  @override
  Future<void> markRepliesRead() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSupportService extends CounsellingService {
  List<CounsellingSession> sessions = [];
  Map<String, String>? request;
  bool failCreate = false;
  bool failDelete = false;
  final approved = <String>[];
  final declined = <String>[];
  final deleted = <String>[];
  final ended = <String>[];

  @override
  Stream<List<CounsellingSession>> streamAll() => Stream.value(sessions);
  @override
  Stream<CounsellingSession?> streamSession(String id) =>
      Stream.value(sessions.first);
  @override
  Stream<List<ChatMessage>> streamMessages(String sessionId) =>
      Stream.value([]);
  @override
  Future<void> refresh({String? sessionId}) async {}
  @override
  Future<int> purgeExpired({bool asAdmin = false}) async => 0;
  @override
  Future<String> createSession(
      {required String name,
      required String age,
      required String gender,
      required String phone,
      required String concern,
      required String language,
      required String details}) async {
    request = {
      'name': name,
      'concern': concern,
      'language': language,
      'details': details
    };
    if (failCreate) throw Exception('offline');
    return 'created';
  }

  @override
  Future<void> approve(String sessionId) async => approved.add(sessionId);
  @override
  Future<void> reject(String sessionId) async => declined.add(sessionId);
  @override
  Future<void> endSession(String sessionId) async => ended.add(sessionId);
  @override
  Future<void> deleteSession(String sessionId) async {
    if (failDelete) throw Exception('offline');
    deleted.add(sessionId);
  }
}

CounsellingSession session(
        {CounsellingStatus status = CounsellingStatus.paymentSubmitted}) =>
    CounsellingSession(
      id: 'only-this-session',
      uid: 'test-member',
      name: 'Test member',
      createdAt: DateTime(2026, 10, 5),
      concern: 'School, exams or study pressure',
      language: 'Hinglish',
      details: 'Tests and homework have felt difficult recently.',
      status: status,
    );

Future<void> pumpSupport(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => SupportTestAuth()),
        ChangeNotifierProvider<NotificationCenter>(
            create: (_) => SupportTestNotifications()),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.4),
                disableAnimations: true),
            child: child!),
        home: Scaffold(body: child),
      )));
  await tester.pumpAndSettle();
}

Future<void> showAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'intake requires chosen topic and retains Other draft after failed submission',
      (tester) async {
    final service = FakeSupportService()..failCreate = true;
    await pumpSupport(tester,
        CounsellingIntakeForm(service: service, initialName: 'Test member'));
    await showAndTap(tester, find.text('Request a conversation'));
    expect(service.request, isNull);
    expect(find.text('Choose a topic, or select Other / not sure.'),
        findsOneWidget);
    await showAndTap(tester, find.byKey(const ValueKey('choose-concerns')));
    await tester.enterText(
        find.byKey(const ValueKey('search-concerns')), 'other');
    await tester.pumpAndSettle();
    await tester.tap(find.text(Counselling.otherConcern));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done · 1/3 selected'));
    await tester.pumpAndSettle();
    final details = find.byWidgetPredicate((w) =>
        w is TextField &&
        w.decoration?.labelText == 'What would you like support with?');
    await tester.ensureVisible(details);
    await tester.enterText(
        details, 'Aaj kal padhai ka pressure zyada lagta hai.');
    await showAndTap(tester, find.text('Request a conversation'));
    expect(
        find.text(
            'Could not send your request. Your writing is still here; please retry.'),
        findsOneWidget);
    expect(service.request?['concern'], Counselling.otherConcern);
    expect(service.request?['language'], 'Hinglish');
    expect(find.text('Aaj kal padhai ka pressure zyada lagta hai.'),
        findsOneWidget);
    service.failCreate = false;
    await showAndTap(tester, find.text('Request a conversation'));
    expect(service.request?['details'],
        'Aaj kal padhai ka pressure zyada lagta hai.');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'topic picker limits selection to three and cancel preserves selection',
      (tester) async {
    await pumpSupport(
        tester, CounsellingIntakeForm(service: FakeSupportService()));
    await showAndTap(tester, find.byKey(const ValueKey('choose-concerns')));
    for (final concern in Counselling.concerns.take(3)) {
      await tester.tap(find.text(concern));
      await tester.pumpAndSettle();
    }
    await tester.enterText(
        find.byKey(const ValueKey('search-concerns')), 'School');
    await tester.pumpAndSettle();
    final fourth =
        find.widgetWithText(CheckboxListTile, Counselling.concerns[3]);
    expect(tester.widget<CheckboxListTile>(fourth).onChanged, isNull);
    await tester.tap(find.text('Done · 3/3 selected'));
    await tester.pumpAndSettle();
    expect(find.text('Change topics (3)'), findsOneWidget);
    await showAndTap(tester, find.byKey(const ValueKey('choose-concerns')));
    await tester.tap(find.text(Counselling.concerns.first).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close topics'));
    await tester.pumpAndSettle();
    expect(find.text('Change topics (3)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final approve in [true, false]) {
    testWidgets(
        'admin can ${approve ? 'approve' : 'decline'} a waiting request',
        (tester) async {
      final service = FakeSupportService()..sessions = [session()];
      await pumpSupport(tester, CounsellingInboxScreen(service: service));
      await showAndTap(tester, find.text('Review request'));
      expect(find.text('Review support request'), findsOneWidget);
      await tester.tap(find.text(approve ? 'Approve chat' : 'Decline'));
      await tester.pumpAndSettle();
      expect(
          approve ? service.approved : service.declined, ['only-this-session']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('closed requests offer delete but cannot be approved again',
      (tester) async {
    final service = FakeSupportService()
      ..sessions = [session(status: CounsellingStatus.rejected)];
    await pumpSupport(tester, CounsellingInboxScreen(service: service));
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Delete conversation'), findsOneWidget);
    expect(find.text('Review request'), findsNothing);
    expect(find.text('Review'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'delete needs confirmation and keeps errors visible until retry succeeds',
      (tester) async {
    final service = FakeSupportService()..failDelete = true;
    await pumpSupport(
        tester,
        Builder(
            builder: (context) => TextButton(
                  onPressed: () => confirmCounsellingAction(
                      context: context,
                      service: service,
                      session: session(),
                      action: CounsellingAction.delete),
                  child: const Text('Open delete'),
                )));
    await tester.tap(find.text('Open delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.deleted, isEmpty);
    await tester.tap(find.text('Open delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete conversation'));
    await tester.pumpAndSettle();
    expect(find.text('Could not delete the conversation. Please retry.'),
        findsOneWidget);
    expect(service.deleted, isEmpty);
    service.failDelete = false;
    await tester.tap(find.text('Delete conversation'));
    await tester.pumpAndSettle();
    expect(service.deleted, ['only-this-session']);
    expect(find.text('Delete this conversation?'), findsNothing);
  });

  testWidgets('member chat has no admin-only end or delete controls',
      (tester) async {
    final service = FakeSupportService()
      ..sessions = [session(status: CounsellingStatus.active)];
    await pumpSupport(tester,
        CounsellingChatView(sessionId: 'only-this-session', service: service));
    expect(find.text('End session'), findsNothing);
    expect(find.byTooltip('Conversation actions'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin chat can end session after confirmation', (tester) async {
    final service = FakeSupportService()
      ..sessions = [session(status: CounsellingStatus.active)];
    await pumpSupport(
        tester,
        CounsellingChatView(
            sessionId: 'only-this-session', asAdmin: true, service: service));
    await tester.tap(find.byTooltip('Conversation actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    expect(service.ended, isEmpty);
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    expect(service.ended, ['only-this-session']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
