import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:brahma_app/core/theme/app_theme.dart';
import 'package:brahma_app/providers/auth_provider.dart' as app;
import 'package:brahma_app/screens/auth/welcome_screen.dart';
import 'package:brahma_app/screens/reset/quick_reset_screen.dart';
import 'package:brahma_app/widgets/avatar_picker_sheet.dart';
import 'package:brahma_app/widgets/weekly_reflection_card.dart';
import 'package:brahma_app/models/journal_entry.dart';
import 'package:brahma_app/models/quick_reset.dart';
import '../test/reset_flow_test.dart' as flows;

/// Runs real widgets on Android with isolated auth/API fixtures. Never writes
/// test journal entries into a production member's account.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  flows.main();

  testWidgets('capture release screens with fictional preview data', (tester) async {
    final auth = flows.GuestAuth();
    final router = GoRouter(initialLocation: '/welcome', routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/reset', builder: (_, __) => const QuickResetScreen()),
      GoRoute(path: '/pictures', builder: (_, __) => const Scaffold(body: AvatarPickerSheet())),
      GoRoute(path: '/week', builder: (_, __) => Scaffold(appBar: AppBar(title: const Text('Your week')),
        body: Padding(padding: const EdgeInsets.all(24), child: WeeklyReflectionCard(entries: [
          for (var day = 0; day < 4; day++) JournalEntry(uid: 'preview-only', mood: 3,
            createdAt: DateTime.now().subtract(Duration(days: day)),
            checkIn: {'reset_topic': 'Studies', 'reset_next_step': 'Choose one task for tomorrow'}),
        ])))),
    ]);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    QuickReset.pending = null;
    await tester.pumpWidget(ChangeNotifierProvider<app.AuthProvider>.value(value: auth,
        child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: AppTheme.darkTheme, routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!))));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    Future<void> capture(String name) async {
      final bytes = await binding.takeScreenshot(name);
      final directory = await getTemporaryDirectory();
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
    }
    await capture('01-welcome');
    router.go('/reset');
    await tester.pumpAndSettle();
    await capture('02-reset-start');
    await tester.tap(find.text('Okay'));
    await tester.tap(find.text('Studies'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose one next step'));
    await tester.tap(find.text('Choose one next step'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose one task for tomorrow'));
    await tester.tap(find.text('Choose one task for tomorrow'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finish my reset'));
    await tester.tap(find.text('Finish my reset'));
    await tester.pumpAndSettle();
    await capture('03-reset-result');
    router.go('/pictures');
    await tester.pumpAndSettle();
    await capture('04-profile-pictures');
    router.go('/week');
    await tester.pumpAndSettle();
    await capture('05-weekly-reflection-preview');
    expect(tester.takeException(), isNull);
  });
}
