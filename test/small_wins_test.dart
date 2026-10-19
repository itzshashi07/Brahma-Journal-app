import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:brahma_app/core/theme/app_theme.dart';
import 'package:brahma_app/screens/gratitude/small_wins_screen.dart';
import 'package:brahma_app/screens/gita/gita_screen.dart';
import 'package:brahma_app/services/small_wins_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeWins extends SmallWinsService {
  bool failLoad = false, failSave = false;
  List<Map<String, dynamic>> entries = [];
  @override
  Future<List<Map<String, dynamic>>> load() async {
    if (failLoad) throw Exception('offline');
    return entries;
  }

  @override
  Future<void> save(
      {required String day,
      required String gratitude,
      required String smallWin,
      required String nextStep}) async {
    if (failSave) throw Exception('offline');
    entries = [
      {
        'day': day,
        'gratitude': gratitude,
        'smallWin': smallWin,
        'nextStep': nextStep
      }
    ];
  }
}

Future<void> show(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.4)),
          child: child!),
      home: screen));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('load failure offers retry before editing saved private words',
      (tester) async {
    final service = FakeWins()..failLoad = true;
    await show(tester, SmallWinsScreen(service: service));
    expect(find.byType(TextField), findsNothing);
    service.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.labelText == 'Something I appreciate'),
        200);
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('save failure retains input; successful retry survives reopening',
      (tester) async {
    final service = FakeWins()..failSave = true;
    await show(tester, SmallWinsScreen(service: service));
    await tester.scrollUntilVisible(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.labelText == 'Something I appreciate'),
        200);
    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.labelText == 'Something I appreciate'),
        'A quiet walk with a friend');
    await tester.scrollUntilVisible(find.text('Keep this moment'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Keep this moment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep this moment'));
    await tester.pumpAndSettle();
    expect(
        find.text('Could not save. Your words are still here; please retry.'),
        findsOneWidget);
    expect(service.entries, isEmpty);
    service.failSave = false;
    await tester.tap(find.text('Keep this moment'));
    await tester.pumpAndSettle();
    expect(service.entries.single['gratitude'], 'A quiet walk with a friend');
    expect(service.entries.single['day'],
        DateFormat('yyyy-MM-dd').format(DateTime.now()));
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, SmallWinsScreen(service: service));
    await tester.scrollUntilVisible(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.labelText == 'Something I appreciate'),
        200);
    final field = tester.widget<TextField>(find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.labelText == 'Something I appreciate'));
    expect(field.controller!.text, 'A quiet walk with a friend');
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('everyday wisdom fits narrow large-text screens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await show(tester, const GitaScreen());
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
