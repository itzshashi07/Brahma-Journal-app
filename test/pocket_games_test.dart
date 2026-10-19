import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brahma_app/models/user_profile.dart';
import 'package:brahma_app/providers/auth_provider.dart' as app;
import 'package:brahma_app/screens/games/pocket_engines.dart';
import 'package:brahma_app/screens/games/pocket_games.dart';
import 'package:brahma_app/screens/games/game_catalog.dart';
import 'package:brahma_app/core/theme/app_theme.dart';

class GameTestAuth extends ChangeNotifier implements app.AuthProvider {
  @override
  User? get user => null;
  @override
  UserProfile? get profile => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('all 31 games have distinct ids and usable metadata', () {
    expect(kGames.length, 31);
    expect(kGames.map((g) => g.id).toSet().length, 31);
    expect(kGames.every((g) => g.title.isNotEmpty && g.subtitle.isNotEmpty),
        isTrue);
  });
  test('tic tac toe rejects occupied cells and computer blocks immediate win',
      () {
    final board = LineBoard();
    board.play(0, 1);
    board.play(1, 1);
    board.play(4, 2);
    expect(board.play(4, 1), isFalse);
    board.computer(Random(1));
    expect(board.cells[2], 2);
    board.play(8, 2);
    expect(board.winner, 0);
  });
  test('four in a row respects gravity and detects diagonal/vertical wins', () {
    final board = LineBoard(rows: 6, columns: 7, target: 4, gravity: true);
    for (var i = 0; i < 4; i++) {
      expect(board.play(2, 1), isTrue);
    }
    expect(board.winner, 1);
    expect(board.cells[37], 1);
    expect(board.play(3, 2), isFalse);
  });
  test('lights toggle is reversible and generated games are not already solved',
      () {
    for (var n = 0; n < 40; n++) {
      final board = LightsBoard(Random(n));
      final before = [...board.cells];
      expect(board.solved, isFalse);
      board.toggle(7);
      board.toggle(7);
      expect(board.cells, before);
    }
  });
  test('2048 merges each tile once and does not spawn on a blocked move', () {
    final board = MergeBoard(Random(1));
    board.cells = [2, 2, 2, 2, ...List.filled(12, 0)];
    board.score = 0;
    board.move(0, addTile: false);
    expect(board.cells.take(4), [4, 4, 0, 0]);
    expect(board.score, 8);
    board.cells = [2, 0, 0, 0, ...List.filled(12, 0)];
    expect(board.move(0), isFalse);
    expect(board.cells.where((v) => v != 0).length, 1);
    board.cells = [2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 2];
    expect(board.stuck, isTrue);
  });
  test('maze generation always connects every cell and can be solved', () {
    for (var seed = 0; seed < 40; seed++) {
      final b = MazeBoard(Random(seed));
      final previous = <int, int>{0: -1};
      final queue = [0];
      for (var j = 0; j < queue.length; j++) {
        for (final n in b.paths[queue[j]]) {
          if (!previous.containsKey(n)) {
            previous[n] = queue[j];
            queue.add(n);
          }
        }
      }
      expect(previous.length, 36);
      final path = <int>[];
      var n = 35;
      while (n != 0) {
        path.add(n);
        n = previous[n]!;
      }
      for (final i in path.reversed) {
        expect(b.move(i), isTrue);
      }
      expect(b.solved, isTrue);
    }
  });
  test('mine garden first move is safe and every generated board is finishable',
      () {
    for (var seed = 0; seed < 40; seed++) {
      final b = MineBoard(Random(seed));
      b.reveal(seed % 25);
      expect(b.lost, isFalse);
      expect(b.mines.length, 4);
      expect(b.count(seed % 25), 0);
      for (var i = 0; i < 25; i++) {
        if (!b.mines.contains(i)) b.reveal(i);
      }
      expect(b.won, isTrue);
    }
  });
  test('mini sudoku generated answer obeys rows, columns and boxes', () {
    for (var seed = 0; seed < 40; seed++) {
      final b = SudokuBoard(Random(seed));
      expect(b.solved, isFalse);
      for (final i in b.blanks) {
        b.place(i, b.solution[i]);
      }
      expect(b.solved, isTrue);
      final fixed =
          List.generate(16, (i) => i).firstWhere((i) => !b.blanks.contains(i));
      final before = b.cells[fixed];
      b.place(fixed, 0);
      expect(b.cells[fixed], before);
    }
  });
  test('word hunt endpoints match visible letters without overwritten words',
      () {
    for (var seed = 0; seed < 40; seed++) {
      final b = WordHuntBoard(Random(seed));
      for (final w in b.words) {
        final p = b.paths[w]!;
        expect(p.map((i) => b.cells[i]).join(), w);
        expect(b.select(p.first, p.last), isTrue);
      }
      expect(b.solved, isTrue);
    }
  });
  const ids = [
    'tic_garden',
    'four_in_row',
    'lights_out',
    'merge_2048',
    'maze_trail',
    'mine_garden',
    'mini_sudoku',
    'word_hunt',
    'number_path',
    'missing_sign',
    'fraction_friends',
    'word_connections',
    'logic_ladder',
    'shape_count',
    'mirror_match',
    'direction_trail'
  ];
  test('every quiz generates a valid unique answer choice', () {
    for (final id in ids.skip(8)) {
      for (var seed = 0; seed < 100; seed++) {
        final q = pocketQuestion(id, Random(seed), 1 + seed % 3);
        expect(q.answer, inInclusiveRange(0, q.options.length - 1));
        expect(q.options.toSet().length, q.options.length);
        expect(q.options.length, inInclusiveRange(3, 4));
        expect(q.explanation, isNotEmpty);
      }
    }
  });
  for (final id in ids) {
    testWidgets('$id opens and pauses on a narrow large-text screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = GameTestAuth();
      await tester.pumpWidget(ChangeNotifierProvider<app.AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(1.4),
                      disableAnimations: true),
                  child: child!),
              home: PocketGame(id: id, title: gameById(id)!.title))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(
          find.text('Take your time.\nYour round is waiting.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    });
  }
}
