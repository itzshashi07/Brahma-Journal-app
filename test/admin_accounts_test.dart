import 'dart:async';

import 'package:brahma_app/core/theme/app_theme.dart';
import 'package:brahma_app/providers/auth_provider.dart';
import 'package:brahma_app/screens/admin/accounts_screen.dart';
import 'package:brahma_app/services/admin_accounts_service.dart';
import 'package:brahma_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class TestAdminAuth extends ChangeNotifier implements AuthProvider {
  TestAdminAuth(this.isAdmin);
  @override
  final bool isAdmin;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const member = AdminAccount(
    uid: 'member-uid', name: 'Test member', email: 'member@example.com');
const second = AdminAccount(
    uid: 'second-uid', name: 'Second member', email: 'second@example.com');

class FakeAccountsService extends AdminAccountsService {
  List<AdminAccount> accounts = [member];
  String? nextCursor;
  final requests = <({String query, String? cursor})>[];
  final actions =
      <({String uid, String action, String reason, String confirmation})>[];
  final pendingLists = <String, Completer<AdminAccountsPage>>{};
  Completer<void>? pendingAction;
  bool failAction = false;
  bool failMore = false;

  @override
  Future<AdminAccountsPage> list({String query = '', String? cursor}) async {
    requests.add((query: query, cursor: cursor));
    if (pendingLists.containsKey(query)) return pendingLists[query]!.future;
    if (cursor != null && failMore)
      throw ApiException(0, 'Connection interrupted.');
    return AdminAccountsPage(
        accounts: cursor == null ? accounts : [second],
        nextCursor: cursor == null ? nextCursor : null);
  }

  @override
  Future<AdminAccountDetails> details(String uid) async => AdminAccountDetails(
          account: accounts.firstWhere((a) => a.uid == uid),
          summary: const {
            'journalEntries': 7,
            'smallWins': 2,
            'thoughts': 3,
            'replies': 4,
            'counsellingSessions': 1,
            'gameScores': 5
          });

  @override
  Future<void> act(
      {required String uid,
      required String action,
      required String reason,
      required String confirmation}) async {
    actions.add(
        (uid: uid, action: action, reason: reason, confirmation: confirmation));
    if (failAction) throw ApiException(503, 'Account cleanup needs a retry.');
    if (pendingAction != null) await pendingAction!.future;
    if (action == 'delete') accounts.removeWhere((a) => a.uid == uid);
  }
}

Future<void> pumpAccounts(WidgetTester tester, FakeAccountsService service,
    {bool admin = true, double textScale = 1.4}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
    create: (_) => TestAdminAuth(admin),
    child: MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (_, child) => MediaQuery(
            data: MediaQueryData(
                size: const Size(360, 800),
                textScaler: TextScaler.linear(textScale),
                disableAnimations: true),
            child: child!),
        home: AdminAccountsScreen(service: service)),
  ));
  await tester.pumpAndSettle();
}

Future<void> showDetailsElement(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 250,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('admin-user-details-list')),
                matching: find.byType(Scrollable))
            .first);
  }
}

Future<void> showTap(WidgetTester tester, Finder finder) async {
  await showDetailsElement(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openAction(WidgetTester tester, String action) async {
  await showTap(tester, find.byKey(const ValueKey('admin-user-member-uid')));
  await showTap(tester, find.byKey(ValueKey('admin-action-$action')));
}

Future<void> enterConfirmation(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('admin-action-reason')),
      'Disposable test cleanup');
  await tester.enterText(
      find.byKey(const ValueKey('admin-action-confirmation')), member.email);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('non-admin never requests or sees account records',
      (tester) async {
    final service = FakeAccountsService();
    await pumpAccounts(tester, service, admin: false);
    expect(find.text('Admins only.'), findsOneWidget);
    expect(service.requests, isEmpty);
  });

  testWidgets(
      'search retains query across pagination and retry keeps loaded rows',
      (tester) async {
    final service = FakeAccountsService()..nextCursor = 'page-two';
    await pumpAccounts(tester, service);
    await tester.enterText(find.byKey(const ValueKey('admin-user-search')),
        '  member@example.com  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(service.requests.last, (query: 'member@example.com', cursor: null));
    service.failMore = true;
    await showTap(tester, find.byKey(const ValueKey('admin-load-more')));
    expect(find.text('Test member'), findsOneWidget);
    expect(find.text('Connection interrupted.'), findsOneWidget);
    service.failMore = false;
    await showTap(tester, find.byKey(const ValueKey('admin-load-more')));
    expect(service.requests.last,
        (query: 'member@example.com', cursor: 'page-two'));
    expect(find.text('Second member'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-load-more')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late search response cannot replace the latest search',
      (tester) async {
    final service = FakeAccountsService();
    await pumpAccounts(tester, service);
    service.pendingLists['old'] = Completer<AdminAccountsPage>();
    await tester.enterText(
        find.byKey(const ValueKey('admin-user-search')), 'old');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    service.accounts = [second];
    await tester.enterText(
        find.byKey(const ValueKey('admin-user-search')), 'new');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    service.pendingLists['old']!
        .complete(const AdminAccountsPage(accounts: [member]));
    await tester.pumpAndSettle();
    expect(find.text('Second member'), findsOneWidget);
    expect(find.text('Test member'), findsNothing);
  });

  testWidgets('protected account shows counts and no destructive controls',
      (tester) async {
    final service = FakeAccountsService()
      ..accounts = [
        const AdminAccount(
            uid: 'admin',
            name: 'Administrator',
            email: 'admin@example.com',
            protected: true)
      ];
    await pumpAccounts(tester, service);
    await showTap(tester, find.byKey(const ValueKey('admin-user-admin')));
    expect(
        find.text('Activity counts only. Private writing is not shown here.'),
        findsOneWidget);
    expect(find.text('Journal entries'), findsOneWidget);
    await showDetailsElement(
        tester, find.textContaining('administrator accounts are protected'));
    expect(find.byKey(const ValueKey('admin-action-delete')), findsNothing);
    expect(find.byKey(const ValueKey('admin-action-reset_data')), findsNothing);
    expect(find.byKey(const ValueKey('admin-action-ban')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'delete requires exact confirmation and retains drafts on server failure',
      (tester) async {
    final service = FakeAccountsService()..failAction = true;
    await pumpAccounts(tester, service);
    await openAction(tester, 'delete');
    await showTap(tester, find.byKey(const ValueKey('admin-confirm-action')));
    expect(service.actions, isEmpty);
    await enterConfirmation(tester);
    await showTap(tester, find.byKey(const ValueKey('admin-confirm-action')));
    expect(find.text('Account cleanup needs a retry.'), findsOneWidget);
    expect(find.text('Disposable test cleanup'), findsOneWidget);
    expect(service.actions.single.action, 'delete');
    service.failAction = false;
    await showTap(tester, find.byKey(const ValueKey('admin-confirm-action')));
    expect(find.text('User details'), findsNothing);
    expect(find.text('No users found.'), findsOneWidget);
    expect(service.actions.last.confirmation, member.email);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reset keeps distinct action and blocks repeated submission while waiting',
      (tester) async {
    final service = FakeAccountsService()..pendingAction = Completer<void>();
    await pumpAccounts(tester, service);
    await openAction(tester, 'reset_data');
    expect(find.textContaining('Keep their sign-in, basic profile'),
        findsOneWidget);
    await enterConfirmation(tester);
    final submit = find.byKey(const ValueKey('admin-confirm-action'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    expect(service.actions, hasLength(1));
    expect(service.actions.single.action, 'reset_data');
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull);
    service.pendingAction!.complete();
    await tester.pumpAndSettle();
    expect(find.text('User details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfinished reset only offers retry of the same cleanup',
      (tester) async {
    final service = FakeAccountsService()
      ..accounts = [
        const AdminAccount(
            uid: 'member-uid',
            name: 'Test member',
            email: 'member@example.com',
            banned: true,
            cleanupPending: true,
            pendingAction: 'reset_data')
      ];
    await pumpAccounts(tester, service);
    await showTap(tester, find.byKey(const ValueKey('admin-user-member-uid')));
    await showDetailsElement(
        tester, find.byKey(const ValueKey('admin-action-reset_data')));
    expect(
        find.byKey(const ValueKey('admin-action-reset_data')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-action-delete')), findsNothing);
    expect(find.byKey(const ValueKey('admin-action-unban')), findsNothing);
  });

  testWidgets('missing sign-in identity offers only remaining data deletion',
      (tester) async {
    final service = FakeAccountsService()
      ..accounts = [
        const AdminAccount(
            uid: 'member-uid',
            name: 'Test member',
            email: '',
            identityMissing: true)
      ];
    await pumpAccounts(tester, service);
    await showTap(tester, find.byKey(const ValueKey('admin-user-member-uid')));
    await showDetailsElement(tester, find.text('Delete remaining app data'));
    expect(find.text('Delete remaining app data'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-action-reset_data')), findsNothing);
    expect(find.byKey(const ValueKey('admin-action-ban')), findsNothing);
    await showTap(tester, find.byKey(const ValueKey('admin-action-delete')));
    expect(find.text('Type user ID to confirm'), findsOneWidget);
    expect(find.textContaining('Sign-in is already removed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
