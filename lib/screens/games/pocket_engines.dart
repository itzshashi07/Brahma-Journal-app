import 'dart:math';

/// Pure game rules, shared by the UI and regression tests.
class LineBoard {
  LineBoard(
      {this.rows = 3, this.columns = 3, this.target = 3, this.gravity = false})
      : cells = List.filled(rows * columns, 0);
  final int rows, columns, target;
  final bool gravity;
  final List<int> cells;
  int winner = 0;
  bool get finished => winner != 0 || !cells.contains(0);
  int position(int tap) {
    if (!gravity) return tap;
    final column = tap % columns;
    for (var row = rows - 1; row >= 0; row--) {
      final i = row * columns + column;
      if (cells[i] == 0) return i;
    }
    return -1;
  }

  bool play(int tap, int player) {
    if (finished || tap < 0 || tap >= cells.length) return false;
    final i = position(tap);
    if (i < 0 || cells[i] != 0) return false;
    cells[i] = player;
    winner = findWinner();
    return true;
  }

  int findWinner() {
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] == 0) continue;
      for (final d in [(0, 1), (1, 0), (1, 1), (1, -1)]) {
        var found = true;
        for (var n = 1; n < target; n++) {
          final r = i ~/ columns + d.$1 * n, c = i % columns + d.$2 * n;
          if (r < 0 ||
              c < 0 ||
              r >= rows ||
              c >= columns ||
              cells[r * columns + c] != cells[i]) {
            found = false;
            break;
          }
        }
        if (found) return cells[i];
      }
    }
    return 0;
  }

  void computer(Random random) {
    if (finished) return;
    final choices = (gravity
            ? List.generate(columns, (i) => i)
            : List.generate(cells.length, (i) => i))
        .where((i) => position(i) >= 0 && cells[position(i)] == 0)
        .toList();
    for (final p in [2, 1]) {
      for (final tap in choices) {
        final i = position(tap);
        cells[i] = p;
        final wins = findWinner() == p;
        cells[i] = 0;
        if (wins) {
          play(tap, 2);
          return;
        }
      }
    }
    final center = choices.where((i) => i % columns == columns ~/ 2).toList();
    play(
        center.isNotEmpty
            ? center[random.nextInt(center.length)]
            : choices[random.nextInt(choices.length)],
        2);
  }
}

class LightsBoard {
  LightsBoard(Random random, {int scramble = 9}) {
    for (var n = 0; n < scramble; n++) {
      toggle(random.nextInt(16));
    }
    if (solved) toggle(5);
    moves = 0;
  }
  final cells = List.filled(16, false);
  int moves = 0;
  bool get solved => cells.every((v) => !v);
  void toggle(int i) {
    for (final j in [
      i,
      if (i % 4 > 0) i - 1,
      if (i % 4 < 3) i + 1,
      if (i >= 4) i - 4,
      if (i < 12) i + 4
    ]) {
      cells[j] = !cells[j];
    }
    moves++;
  }
}

class MergeBoard {
  MergeBoard(this.random) {
    spawn();
    spawn();
  }
  final Random random;
  List<int> cells = List.filled(16, 0);
  int score = 0;
  bool get won => cells.any((v) => v >= 2048);
  bool get stuck {
    if (cells.contains(0)) return false;
    for (var i = 0; i < 16; i++) {
      if (i % 4 < 3 && cells[i] == cells[i + 1]) return false;
      if (i < 12 && cells[i] == cells[i + 4]) return false;
    }
    return true;
  }

  void spawn() {
    final empty =
        List.generate(16, (i) => i).where((i) => cells[i] == 0).toList();
    if (empty.isNotEmpty)
      cells[empty[random.nextInt(empty.length)]] =
          random.nextInt(10) == 0 ? 4 : 2;
  }

  List<int> merge(List<int> row) {
    final nonzero = row.where((v) => v != 0).toList();
    final out = <int>[];
    for (var i = 0; i < nonzero.length; i++) {
      if (i + 1 < nonzero.length && nonzero[i] == nonzero[i + 1]) {
        out.add(nonzero[i] * 2);
        score += nonzero[i] * 2;
        i++;
      } else {
        out.add(nonzero[i]);
      }
    }
    return [...out, ...List.filled(4 - out.length, 0)];
  }

  bool move(int direction, {bool addTile = true}) {
    final before = cells.join(',');
    for (var n = 0; n < 4; n++) {
      final indexes = List.generate(
          4,
          (j) => switch (direction) {
                0 => n * 4 + j,
                1 => n * 4 + 3 - j,
                2 => j * 4 + n,
                _ => (3 - j) * 4 + n,
              });
      final merged = merge(indexes.map((i) => cells[i]).toList());
      for (var j = 0; j < 4; j++) {
        cells[indexes[j]] = merged[j];
      }
    }
    final changed = before != cells.join(',');
    if (changed && addTile) spawn();
    return changed;
  }
}

class MazeBoard {
  MazeBoard(this.random) {
    _carve(0);
  }
  final Random random;
  final paths = List.generate(36, (_) => <int>{});
  final _visited = <int>{};
  int position = 0, moves = 0;
  bool get solved => position == 35;
  void _carve(int cell) {
    _visited.add(cell);
    final neighbors = [
      if (cell % 6 > 0) cell - 1,
      if (cell % 6 < 5) cell + 1,
      if (cell >= 6) cell - 6,
      if (cell < 30) cell + 6
    ]..shuffle(random);
    for (final n in neighbors) {
      if (_visited.contains(n)) continue;
      paths[cell].add(n);
      paths[n].add(cell);
      _carve(n);
    }
  }

  bool move(int next) {
    if (solved || !paths[position].contains(next)) return false;
    position = next;
    moves++;
    return true;
  }
}

class MineBoard {
  MineBoard(this.random);
  final Random random;
  final mines = <int>{}, open = <int>{}, flags = <int>{};
  bool lost = false;
  bool get won => open.length == 21;
  List<int> around(int i) => [
        for (var r = max(0, i ~/ 5 - 1); r <= min(4, i ~/ 5 + 1); r++)
          for (var c = max(0, i % 5 - 1); c <= min(4, i % 5 + 1); c++)
            if (r * 5 + c != i) r * 5 + c
      ];
  int count(int i) => around(i).where(mines.contains).length;
  void flag(int i) {
    if (!lost && !won && !open.contains(i)) {
      if (!flags.remove(i)) flags.add(i);
    }
  }

  void reveal(int i) {
    if (lost || won || flags.contains(i) || open.contains(i)) return;
    if (mines.isEmpty) {
      final options = List.generate(25, (n) => n)
          .where((n) => n != i && !around(i).contains(n))
          .toList()
        ..shuffle(random);
      mines.addAll(options.take(4));
    }
    if (mines.contains(i)) {
      lost = true;
      return;
    }
    open.add(i);
    if (count(i) == 0) {
      for (final n in around(i)) {
        reveal(n);
      }
    }
  }
}

class SudokuBoard {
  SudokuBoard(Random random) {
    final values = [1, 2, 3, 4]..shuffle(random);
    solution = List.generate(
        16, (i) => values[((i ~/ 4) * 2 + (i ~/ 4) ~/ 2 + i % 4) % 4]);
    final hide = List.generate(16, (i) => i)..shuffle(random);
    blanks.addAll(hide.take(7));
    cells = List.generate(16, (i) => blanks.contains(i) ? 0 : solution[i]);
  }
  late final List<int> solution;
  late List<int> cells;
  final blanks = <int>{};
  bool validGroup(Iterable<int> indexes) =>
      indexes.map((i) => cells[i]).toSet().length == 4 &&
      indexes.every((i) => cells[i] != 0);
  bool get solved =>
      List.generate(4, (r) => r)
          .every((r) => validGroup(List.generate(4, (c) => r * 4 + c))) &&
      List.generate(4, (c) => c)
          .every((c) => validGroup(List.generate(4, (r) => r * 4 + c))) &&
      [0, 2, 8, 10].every((i) => validGroup([i, i + 1, i + 4, i + 5]));
  void place(int i, int value) {
    if (blanks.contains(i)) cells[i] = value;
  }
}

class WordHuntBoard {
  WordHuntBoard(Random random) {
    const sets = [
      ['CALM', 'KIND', 'REST'],
      ['HOPE', 'CARE', 'GROW'],
      ['PLAY', 'READ', 'WALK'],
      ['STAR', 'MOON', 'GLOW']
    ];
    words = sets[random.nextInt(sets.length)];
    cells =
        List.generate(25, (_) => String.fromCharCode(65 + random.nextInt(26)));
    final vertical = random.nextBool();
    for (var n = 0; n < 3; n++) {
      final start = random.nextInt(2);
      final reverse = random.nextBool();
      final indexes = List.generate(
          4, (j) => vertical ? (start + j) * 5 + n * 2 : n * 10 + start + j);
      paths[words[n]] = reverse ? indexes.reversed.toList() : indexes;
      for (var j = 0; j < 4; j++) {
        cells[paths[words[n]]![j]] = words[n][j];
      }
    }
  }
  late final List<String> words, cells;
  final paths = <String, List<int>>{};
  final found = <String>{};
  bool get solved => found.length == words.length;
  bool select(int first, int last) {
    for (final word in words) {
      final p = paths[word]!;
      if ((p.first == first && p.last == last) ||
          (p.last == first && p.first == last)) {
        found.add(word);
        return true;
      }
    }
    return false;
  }
}

class PocketQuestion {
  const PocketQuestion(
      this.prompt, this.options, this.answer, this.explanation);
  final String prompt, explanation;
  final List<String> options;
  final int answer;
}

PocketQuestion pocketQuestion(String game, Random random, int level) {
  PocketQuestion choices(
      String prompt, String correct, List<String> wrong, String why) {
    final options = {correct, ...wrong.where((v) => v != correct).take(3)}
        .toList()
      ..shuffle(random);
    return PocketQuestion(prompt, options, options.indexOf(correct), why);
  }

  final a = 2 + random.nextInt(5 + level * 4),
      b = 2 + random.nextInt(5 + level * 3);
  switch (game) {
    case 'number_path':
      final step = 2 + random.nextInt(3 + level * 3),
          start = random.nextInt(20);
      return choices(
          '$start, ${start + step}, ${start + step * 2}, ${start + step * 3}, ?',
          '${start + step * 4}',
          [
            '${start + step * 4 + 1}',
            '${start + step * 5}',
            '${start + step * 4 - 1}'
          ],
          'Each number increases by $step.');
    case 'missing_sign':
      final op = random.nextInt(3), x = a + 3, y = b;
      final result = [x + y, x - y, x * y][op];
      return choices(
          '$x  ?  $y  =  $result',
          ['+', '−', '×'][op],
          ['+', '−', '×'].where((v) => v != ['+', '−', '×'][op]).toList(),
          'Replace the question mark with ${[
            'addition',
            'subtraction',
            'multiplication'
          ][op]}.');
    case 'fraction_friends':
      final c = a + random.nextInt(5) + 1, d = b + random.nextInt(5) + 1;
      final sign = a * d == b * c
          ? '='
          : a * d > b * c
              ? '>'
              : '<';
      return choices(
          '$a/$c  ?  $b/$d',
          sign,
          ['<', '=', '>'].where((v) => v != sign).toList(),
          'Compare $a × $d with $b × $c: ${a * d} and ${b * c}.');
    case 'word_connections':
      const groups = [
        (['apple', 'mango', 'banana'], 'carrot', 'The first three are fruits.'),
        (
          ['bus', 'train', 'bicycle'],
          'pillow',
          'The first three are transport.'
        ),
        (['red', 'blue', 'green'], 'circle', 'The first three are colours.'),
        (
          ['piano', 'flute', 'drum'],
          'paintbrush',
          'The first three are musical instruments.'
        ),
        (['Monday', 'Friday', 'Sunday'], 'August', 'August is a month.'),
        (['triangle', 'circle', 'square'], 'purple', 'Purple is a colour.'),
        (
          ['sparrow', 'eagle', 'parrot'],
          'rabbit',
          'The first three are birds.'
        ),
        (
          ['winter', 'summer', 'spring'],
          'midnight',
          'Midnight is a time of day.'
        ),
        (['cup', 'plate', 'bowl'], 'sock', 'The first three belong at a meal.'),
        (
          ['read', 'write', 'draw'],
          'yellow',
          'Yellow is a colour, not an action.'
        )
      ];
      final g = groups[random.nextInt(groups.length)];
      return choices(
          'Which one belongs to a different group?', g.$2, g.$1, g.$3);
    case 'logic_ladder':
      const qs = [
        PocketQuestion(
            'Asha is before Ravi. Ravi is before Noor. Who is first?',
            ['Asha', 'Ravi', 'Noor'],
            0,
            'Asha → Ravi → Noor.'),
        PocketQuestion(
            'All roses are flowers. Does that mean all flowers are roses?',
            ['Yes', 'No', 'Only red ones'],
            1,
            'Roses are one kind of flower; there are other kinds.'),
        PocketQuestion(
            'You face north, turn right, then turn right again. Where do you face?',
            ['South', 'East', 'West'],
            0,
            'North → East → South.'),
        PocketQuestion(
            'A box has only red balls. You take one without looking. What colour is it?',
            ['Red', 'Blue', 'Cannot know'],
            0,
            'Every ball in this box is red.'),
        PocketQuestion(
            'Today is Tuesday. What day is it after three days?',
            ['Thursday', 'Friday', 'Saturday'],
            1,
            'Wednesday is one, Thursday two, Friday three.'),
        PocketQuestion(
            'A book costs more than a pen. A pen costs more than an eraser. What costs least?',
            ['Book', 'Pen', 'Eraser'],
            2,
            'Book > pen > eraser.'),
        PocketQuestion(
            'Some cats are black. Can we be sure every cat is black?',
            ['Yes', 'No', 'Only at night'],
            1,
            'Some does not mean all.'),
        PocketQuestion(
            'Mira has twice as many marbles as Jo. Jo has 3. How many does Mira have?',
            ['5', '6', '9'],
            1,
            'Twice 3 is 6.'),
      ];
      return qs[random.nextInt(qs.length)];
    case 'shape_count':
      const symbols = ['●', '▲', '■', '★'];
      final target = symbols[random.nextInt(4)];
      final items =
          List.generate(12 + level * 4, (_) => symbols[random.nextInt(4)]);
      final n = items.where((v) => v == target).length;
      return choices(
          'Count the $target shapes:\n\n${[
            for (var i = 0; i < items.length; i += 4)
              items.skip(i).take(4).join('  ')
          ].join('\n')}',
          '$n',
          ['${n + 1}', '${n + 2}', '${n == 0 ? 3 : n - 1}'],
          'There are $n $target shapes. Count one row at a time.');
    case 'mirror_match':
      final row = random.nextInt(3), col = random.nextInt(3);
      final picture = List.generate(
          3,
          (r) => List.generate(3, (c) => r == row && c == col ? '●' : '·')
              .join('   ')).join('\n');
      final correct = '${row + 1}, ${3 - col}';
      return choices(
          'Mirror this dot left to right.\nWhich row, column holds the reflection?\n\n$picture',
          correct,
          [
            for (var r = 0; r < 3; r++)
              for (var c = 0; c < 3; c++)
                if ('$r,$c' != '$row,${2 - col}') '${r + 1}, ${c + 1}'
          ]..shuffle(random),
          'The row stays ${row + 1}; column ${col + 1} becomes ${3 - col}.');
    default:
      final dirs = List.generate(3 + level, (_) => random.nextInt(4));
      var x = 0, y = 0;
      for (final d in dirs) {
        x += [0, 1, 0, -1][d];
        y += [1, 0, -1, 0][d];
      }
      final answer = '($x, $y)';
      return choices(
          'Start at (0, 0). Follow these steps:\n\n${dirs.map((d) => [
                '↑',
                '→',
                '↓',
                '←'
              ][d]).join('  ')}\n\nRight adds x. Up adds y.',
          answer,
          ['(${x + 1}, $y)', '($x, ${y + 1})', '(${x - 1}, ${y - 1})'],
          'The final position is $answer.');
  }
}
