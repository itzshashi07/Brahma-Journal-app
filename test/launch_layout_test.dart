import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:brahma_app/core/theme/app_theme.dart';
import 'package:brahma_app/screens/auth/welcome_screen.dart';
import 'package:brahma_app/widgets/daily_practice_card.dart';
import 'package:brahma_app/widgets/sacred.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(740, 360)
  ]) {
    testWidgets('welcome fits $size with large text and reachable sign-in',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
        GoRoute(
            path: '/login',
            builder: (_, __) =>
                const Scaffold(body: Text('Login destination'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.6),
                    disableAnimations: true),
                child: child!,
              )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Login destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'practice actions fit narrow screens and remain usable at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var journals = 0;
    var meditations = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
            padding: const EdgeInsets.all(20),
            child: DailyPracticeCard(
                hasEntry: false,
                onJournal: () => journals++,
                onMeditate: () => meditations++),
          ))),
        )));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Write a little'));
    await tester.tap(find.text('Write a little'));
    await tester.ensureVisible(find.text('Or take a breathing break'));
    await tester.tap(find.text('Or take a breathing break'));
    expect(journals, 1);
    expect(meditations, 1);
  });
  testWidgets('loading buttons cannot be submitted twice', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SacredButton(
      label: 'Save',
      loading: true,
      onTap: () => taps++,
    ))));
    await tester.tap(find.byType(ElevatedButton));
    expect(taps, 0);
  });
}
