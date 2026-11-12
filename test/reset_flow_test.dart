import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:brahma_app/core/constants/profile_pictures.dart';
import 'package:brahma_app/core/theme/app_theme.dart';
import 'package:brahma_app/core/utils/route_access.dart';
import 'package:brahma_app/core/utils/weekly_reflection.dart';
import 'package:brahma_app/models/journal_entry.dart';
import 'package:brahma_app/models/quick_reset.dart';
import 'package:brahma_app/providers/auth_provider.dart' as app;
import 'package:brahma_app/providers/journal_provider.dart';
import 'package:brahma_app/services/streak_service.dart';
import 'package:brahma_app/screens/reset/quick_reset_screen.dart';
import 'package:brahma_app/services/api_service.dart';
import 'package:brahma_app/services/avatar_service.dart';
import 'package:brahma_app/services/journal_service.dart';
import 'package:brahma_app/widgets/avatar_picker_sheet.dart';

class GuestAuth extends ChangeNotifier implements app.AuthProvider {
  @override
  bool get isAuthenticated => false;
  @override
  User? get user => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ResetUser extends Fake implements User {
  @override
  String get uid => 'reset-test-member';
}

class SignedInAuth extends GuestAuth {
  final User member = ResetUser();
  @override
  bool get isAuthenticated => true;
  @override
  User get user => member;
  @override
  Future<void> refreshProfile() async {}
}

class SwitchableAuth extends GuestAuth {
  User? current = ResetUser();
  @override
  bool get isAuthenticated => current != null;
  @override
  User? get user => current;
}

class ResetJournal extends JournalService {
  bool offline = false;
  JournalEntry? written;
  String? writtenId;
  final existing = JournalEntry(id: 'existing-entry', uid: 'reset-test-member',
      mood: 3, createdAt: DateTime.now(), craftDone: ['practice'],
      craftMinutes: 35, bestMoment: 'A saved moment');
  @override
  Future<JournalEntry?> getTodaysEntry([String? uid]) async {
    if (offline) throw ApiException(0, 'Offline');
    return existing;
  }
  @override
  Future<String> saveEntry(JournalEntry entry, {String? existingEntryId}) async {
    written = entry;
    writtenId = existingEntryId;
    return existingEntryId ?? 'new-entry';
  }
  @override
  Future<List<JournalEntry>> getEntries([String? uid]) async => [written ?? existing];
}

class ResetStreaks extends StreakService {
  @override
  Future<List<DateTime>> recoveredDays([String? uid]) async => [];
}

class PagedApi extends Fake implements ApiService {
  final queries = <Map<String, String>?>[];
  bool repeatCursor = false;
  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    queries.add(query);
    return {
      'entries': [
        {
          '_id': 'entry-${queries.length}',
          'firebaseUid': 'member',
          'mood': 3,
          'createdAt': DateTime.now().toUtc().toIso8601String()
        }
      ],
      'hasMore': repeatCursor || queries.length == 1,
      'nextCursor': 'next-page',
    };
  }
}

void main() {
  setUp(() => QuickReset.pending = null);
  tearDown(() => QuickReset.pending = null);

  test('guest reset is accessible while private diary stays protected', () {
    expect(
        routeAccessRedirect(
            location: '/reset',
            initializing: false,
            authenticated: false,
            admin: false),
        isNull);
    expect(
        routeAccessRedirect(
            location: '/journal',
            initializing: false,
            authenticated: false,
            admin: false),
        '/welcome');
  });

  test('reset merge keeps craft, habits, prose, dates and previous check-ins',
      () {
    final date = DateTime(2026, 11, 12);
    final existing = JournalEntry(
        id: 'old',
        uid: 'member',
        mood: 3,
        createdAt: date,
        craftDone: ['practice'],
        craftMinutes: 45,
        bestMoment: 'A private moment',
        checkIn: {'day': 'Fine'},
        practices: ['walk'],
        habitsDone: ['read']);
    final reset = QuickReset()
      ..mood = 4
      ..topic = 'Studies'
      ..thought = '  Tomorrow  '
      ..nextStep = '  One task  ';
    final merged = reset.toEntry(uid: 'member', existing: existing);
    expect(merged.id, 'old');
    expect(merged.createdAt, date);
    expect(merged.craftDone, ['practice']);
    expect(merged.craftMinutes, 45);
    expect(merged.habitsDone, ['read']);
    expect(merged.practices, ['walk']);
    expect(merged.bestMoment, 'A private moment');
    expect(merged.checkIn['day'], 'Fine');
    expect(merged.checkIn['reset_next_step'], 'One task');
    expect(merged.mood, 4);
    expect(merged.toJson().containsKey('uid'), isFalse);
  });

  test(
      'weekly summary counts unique days, excludes old/future and requires repetition',
      () {
    final now = DateTime(2026, 11, 12, 20);
    JournalEntry entry(int offset, {String topic = 'Studies', int hour = 12}) =>
        JournalEntry(
            uid: 'm',
            mood: 3,
            createdAt: DateTime(2026, 11, 12 + offset, hour),
            checkIn: {'reset_topic': topic, 'reset_next_step': 'Small step'});
    final result = WeeklyReflection.from([
      entry(0),
      entry(0, hour: 14),
      entry(-1),
      entry(-6, topic: 'Work'),
      entry(-7),
      entry(1),
    ], now);
    expect(result.days, 3);
    expect(result.recurringTopic, 'Studies');
    expect(result.topicDays, 2);
    expect(result.nextStep, 'Small step');
    expect(WeeklyReflection.from([entry(0)], now).recurringTopic, isNull);
  });

  test('journal loads all pages and refuses an endlessly repeated cursor',
      () async {
    final api = PagedApi();
    final entries = await JournalService(api: api).getEntries();
    expect(entries.length, 2);
    expect(api.queries.last?['cursor'], 'next-page');
    final repeated = PagedApi()..repeatCursor = true;
    await expectLater(JournalService(api: repeated).getEntries(),
        throwsA(isA<ApiException>()));
    expect(repeated.queries.length, 2);
  });

  test('six distinct picture IDs; custom avatars fail before a network request',
      () async {
    expect(ProfilePictures.all.length, 6);
    expect(ProfilePictures.all.map((a) => a.id).toSet().length, 6);
    for (final picture in ProfilePictures.all) {
      expect(ProfilePictures.contains(picture.id), isTrue);
    }
    await expectLater(AvatarService().selectAvatar(avatarId: 'm:7,5,8,0,0,5,3'),
        throwsArgumentError);
  });

  testWidgets(
      'guest finishes a reset without backend, then can sign in to save',
      (tester) async {
    final auth = GuestAuth();
    final router = GoRouter(initialLocation: '/reset', routes: [
      GoRoute(path: '/reset', builder: (_, __) => const QuickResetScreen()),
      GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login destination'))),
      GoRoute(
          path: '/welcome',
          builder: (_, __) =>
              const Scaffold(body: Text('Welcome destination'))),
    ]);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<app.AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
            theme: AppTheme.darkTheme, routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Okay'));
    await tester.tap(find.text('Studies'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose one next step'));
    await tester.tap(find.text('Choose one next step'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose one task for tomorrow'));
    await tester.tap(find.text('Choose one task for tomorrow'));
    await tester.pump();
    await tester.ensureVisible(find.text('Finish my reset'));
    await tester.tap(find.text('Finish my reset'));
    await tester.pumpAndSettle();
    expect(find.text('One thing at a time.'), findsOneWidget);
    expect(QuickReset.pending?.nextStep, 'Choose one task for tomorrow');
    expect(QuickReset.pending?.ownerUid, isNull);
    await tester.ensureVisible(find.text('Sign in to save my reset'));
    await tester.tap(find.text('Sign in to save my reset'));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    expect(QuickReset.pending?.completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final offline in [false, true]) {
    testWidgets(offline ? 'offline save retains reset and never reports success'
        : 'signed-in reset updates existing entry without losing craft data', (tester) async {
      final auth = SignedInAuth();
      final service = ResetJournal()..offline = offline;
      final journal = JournalProvider(service: service, streaks: ResetStreaks());
      QuickReset.pending = QuickReset()..mood = 4..topic = 'Studies'
        ..nextStep = 'One manageable task'..completed = true;
      addTearDown(auth.dispose);
      addTearDown(journal.dispose);
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider<app.AuthProvider>.value(value: auth),
        ChangeNotifierProvider<JournalProvider>.value(value: journal),
      ], child: MaterialApp(theme: AppTheme.darkTheme,
          home: QuickResetScreen(journalService: service))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save to my journal'));
      await tester.tap(find.text('Save to my journal'));
      await tester.pumpAndSettle();
      if (offline) {
        expect(find.textContaining('Could not save.'), findsOneWidget);
        expect(find.text('Your reset is saved.'), findsNothing);
        expect(QuickReset.pending?.nextStep, 'One manageable task');
        expect(service.written, isNull);
      } else {
        expect(find.text('Your reset is saved.'), findsOneWidget);
        expect(service.writtenId, 'existing-entry');
        expect(service.written?.craftDone, ['practice']);
        expect(service.written?.craftMinutes, 35);
        expect(service.written?.bestMoment, 'A saved moment');
        expect(QuickReset.pending, isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sign-out hides an already-open private reset', (tester) async {
    final auth = SwitchableAuth();
    QuickReset.pending = QuickReset()..mood = 3..topic = 'Studies'
      ..completed = true..nextStep = 'Private next step';
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<app.AuthProvider>.value(
      value: auth, child: MaterialApp(theme: AppTheme.darkTheme,
        home: const QuickResetScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Private next step'), findsOneWidget);
    auth.current = null;
    auth.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Private next step'), findsNothing);
    expect(find.text('Your sign-in changed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed picture picker returns selected ID with large text',
      (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Builder(
                builder: (context) => Scaffold(
                    body: Center(
                        child: TextButton(
                            onPressed: () async {
                              chosen = await AvatarPickerSheet.show(context);
                            },
                            child: const Text('Choose picture'))))))));
    await tester.tap(find.text('Choose picture'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-picture-5')), findsOneWidget);
    expect(find.text('Shuffle'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('profile-picture-4')));
    await tester.tap(find.byKey(const ValueKey('profile-picture-4')));
    await tester.pumpAndSettle();
    expect(chosen, ProfilePictures.all[4].id);
    expect(tester.takeException(), isNull);
  });
}
