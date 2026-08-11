import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brahma_app/core/constants/meditation_quiz.dart';
import 'package:brahma_app/core/constants/meditation_techniques.dart';
import 'package:brahma_app/screens/meditation/meditation_library_screen.dart';
import 'package:brahma_app/screens/meditation/meditation_quiz_screen.dart';

/// These exist because of a real bug: SectionHeading contains a Spacer, and
/// nesting it inside another Row handed it unbounded width. That throws during
/// layout, and the whole meditation list rendered as an empty screen — visible
/// only by opening the app on a phone. A pump-and-check test catches the entire
/// class of mistake in a second.
void main() {
  testWidgets('meditation library lays out without exceptions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MeditationLibraryScreen()),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('All practices'), findsOneWidget);
    // The first technique in the library should actually be on screen.
    expect(find.text(MeditationTechniques.all.first.name), findsWidgets);
  });

  testWidgets('meditation library filters by tag', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MeditationLibraryScreen(initialTag: MindTag.sleep)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Sleep Wind-Down'), findsWidgets);
  });

  testWidgets('quiz walks through every question and shows results',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MeditationQuizScreen()));
    await tester.pump();

    for (var i = 0; i < MeditationQuiz.questions.length; i++) {
      expect(tester.takeException(), isNull);
      final option = MeditationQuiz.questions[i].options.first.label;
      await tester.tap(find.text(option));
      // pump, not pumpAndSettle: the sacred backdrop carries a mandala that
      // rotates forever, so nothing on these screens ever "settles".
      await tester.pump(const Duration(milliseconds: 350));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('BEST FIT TODAY'), findsOneWidget);
  });

  group('recommendations', () {
    test('a two-minute answer never suggests a twelve-minute practice', () {
      final answers = [
        MeditationQuiz.questions[0].options[1], // tense
        MeditationQuiz.questions[1].options[2], // calm
        MeditationQuiz.questions[2].options[0], // 2 minutes
        MeditationQuiz.questions[3].options[0], // restless
        MeditationQuiz.questions[4].options[3], // nothing specific
      ];
      final picks = MeditationQuiz.recommend(answers);
      expect(picks, isNotEmpty);
      expect(picks.first.minutes, lessThanOrEqualTo(8));
    });

    test('always returns something, even with no useful answers', () {
      expect(MeditationQuiz.recommend([]), isNotEmpty);
    });

    test('every technique has steps and a stated duration', () {
      for (final t in MeditationTechniques.all) {
        expect(t.steps, isNotEmpty, reason: '${t.id} has no steps');
        expect(t.scriptedSeconds, greaterThan(60), reason: '${t.id} too short');
        expect(t.bestFor, isNotEmpty, reason: '${t.id} matches no need');
      }
    });
  });
}
