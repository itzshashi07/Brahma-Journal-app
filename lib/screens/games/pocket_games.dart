import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';
import 'game_core.dart';
import 'pocket_engines.dart';

class PocketGame extends StatefulWidget {
  const PocketGame({super.key, required this.id, required this.title});
  final String id, title;
  @override
  State<PocketGame> createState() => _PocketGameState();
}

class _PocketGameState extends State<PocketGame> with GameSession<PocketGame> {
  final _random = Random();
  late LineBoard _line;
  late LightsBoard _lights;
  late MergeBoard _merge;
  late MazeBoard _maze;
  late MineBoard _mine;
  late SudokuBoard _sudoku;
  late WordHuntBoard _word;
  int? _selected;
  int _moves = 0, _round = 0, _correct = 0, _level = 1;
  bool _finished = false, _flagging = false, _paused = false;
  String _feedback = '';
  int? _answer;
  late PocketQuestion _question;
  @override
  String get gameId => widget.id;
  bool get _quiz => ![
        'tic_garden',
        'four_in_row',
        'lights_out',
        'merge_2048',
        'maze_trail',
        'mine_garden',
        'mini_sudoku',
        'word_hunt'
      ].contains(widget.id);
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _line = widget.id == 'four_in_row'
        ? LineBoard(rows: 6, columns: 7, target: 4, gravity: true)
        : LineBoard();
    _lights = LightsBoard(_random);
    _merge = MergeBoard(_random);
    _maze = MazeBoard(_random);
    _mine = MineBoard(_random);
    _sudoku = SudokuBoard(_random);
    _word = WordHuntBoard(_random);
    _selected = null;
    _moves = 0;
    _round = 0;
    _correct = 0;
    _finished = false;
    _paused = false;
    _feedback = '';
    _answer = null;
    _question = pocketQuestion(widget.id, _random, _level);
  }

  void _finish(String message, {int score = 100}) {
    if (_finished) return;
    _finished = true;
    _feedback = message;
    submitScore(score, lowerIsBetter: false).catchError((_) => null);
  }

  void _tap(int i) {
    if (_finished || _paused) return;
    setState(() {
      switch (widget.id) {
        case 'tic_garden':
        case 'four_in_row':
          if (!_line.play(i, 1)) return;
          _moves++;
          _line.computer(_random);
          if (_line.finished)
            _finish(
                _line.winner == 1
                    ? 'You found the line. Nicely done!'
                    : _line.winner == 2
                        ? 'The garden wins this round. Try another approach.'
                        : 'A thoughtful draw. Well played.',
                score: _line.winner == 1
                    ? 100
                    : _line.winner == 0
                        ? 50
                        : 0);
        case 'lights_out':
          _lights.toggle(i);
          _moves++;
          if (_lights.solved)
            _finish('A quiet sky. Every light is out.',
                score: max(10, 200 - _moves));
        case 'maze_trail':
          if (_maze.move(i)) _moves++;
          if (_maze.solved)
            _finish('You found your way home.', score: max(10, 200 - _moves));
        case 'mine_garden':
          if (_flagging) {
            _mine.flag(i);
          } else {
            _mine.reveal(i);
          }
          _moves++;
          if (_mine.lost)
            _finish('A hidden stone! The numbers guide your next try.',
                score: _mine.open.length);
          if (_mine.won) _finish('All 21 safe spaces found.', score: 100);
        case 'mini_sudoku':
          _selected = i;
        case 'word_hunt':
          if (_selected == null) {
            _selected = i;
          } else {
            _moves++;
            final found = _word.select(_selected!, i);
            _selected = null;
            _feedback = found
                ? 'Word found!'
                : 'Try the first and last letters of a word.';
            if (_word.solved)
              _finish('All three words found. Take a little pause.',
                  score: max(10, 200 - _moves));
          }
      }
    });
  }

  void _moveMerge(int direction) {
    if (_finished || _paused) return;
    setState(() {
      if (_merge.move(direction)) _moves++;
      if (_merge.won)
        _finish('2048! You built it one move at a time.', score: _merge.score);
      else if (_merge.stuck)
        _finish('No moves left. Your score: ${_merge.score}.',
            score: _merge.score);
    });
  }

  String get _instruction => switch (widget.id) {
        'tic_garden' =>
          'You are ×. Make a line of three before the garden does.',
        'four_in_row' =>
          'You are ●. Tap a column to drop a piece. Connect four in any direction.',
        'lights_out' =>
          'Turn every light off. Each tap flips its tile and its immediate neighbours.',
        'merge_2048' =>
          'Slide with the arrows. Equal tiles join once per move. Reach 2048.',
        'maze_trail' =>
          'You are ●. Tap a neighbouring square through an open path. Reach the flag.',
        'mine_garden' =>
          'Find 21 safe spaces. Numbers count nearby hidden stones. Use flag mode to mark a suspect square.',
        'mini_sudoku' =>
          'Each row, column and 2 × 2 box needs 1, 2, 3 and 4 once. Tap a blank, then choose a number.',
        'word_hunt' =>
          'Find each word by tapping its first and last letters. Words run across or down, in either direction.',
        _ =>
          'Eight questions. No timer. Notice the pattern, then choose your answer.',
      };
  Widget _grid(int columns, List<Widget> children) => GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: widget.id == 'maze_trail' ? 0 : 6,
      crossAxisSpacing: widget.id == 'maze_trail' ? 0 : 6,
      children: children);
  Widget _tile(int i, String label,
          {bool selected = false,
          bool fixed = false,
          Color? colour,
          Border? border,
          String? semantics}) =>
      Semantics(
          label:
              semantics ?? 'Cell ${i + 1}, ${label.isEmpty ? 'empty' : label}',
          button: true,
          child: Material(
              color: colour ?? (selected ? AppTheme.primary : AppTheme.bgCard),
              shape: border == null
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: fixed ? AppTheme.textMuted : AppTheme.border))
                  : null,
              child: InkWell(
                  onTap: () => _tap(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                      decoration:
                          border == null ? null : BoxDecoration(border: border),
                      alignment: Alignment.center,
                      child: Text(label,
                          style: TextStyle(
                              fontSize: label.length > 3 ? 17 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white))))));
  Widget _board() {
    switch (widget.id) {
      case 'tic_garden':
      case 'four_in_row':
        return _grid(
            _line.columns,
            List.generate(
                _line.cells.length,
                (i) => _tile(i, ['', '×', '○'][_line.cells[i]],
                    colour: _line.cells[i] == 1
                        ? const Color(0xFF4F35AD)
                        : _line.cells[i] == 2
                            ? const Color(0xFF15615A)
                            : null)));
      case 'lights_out':
        return _grid(
            4,
            List.generate(
                16,
                (i) => _tile(i, _lights.cells[i] ? '☀' : '·',
                    colour: _lights.cells[i] ? const Color(0xFF95601F) : null,
                    semantics:
                        'Light ${i + 1}, ${_lights.cells[i] ? 'on' : 'off'}')));
      case 'merge_2048':
        return Column(children: [
          Text('Score ${_merge.score}', style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 12),
          _grid(
              4,
              List.generate(
                  16,
                  (i) => _tile(
                      i, _merge.cells[i] == 0 ? '' : '${_merge.cells[i]}',
                      colour: _merge.cells[i] == 0
                          ? null
                          : Color.lerp(
                              const Color(0xFF39315C),
                              const Color(0xFF976728),
                              min(1, log(_merge.cells[i]) / log(2) / 11))))),
          const SizedBox(height: 16),
          _arrows(_moveMerge),
          TextButton(
              onPressed: _finished
                  ? null
                  : () => setState(() => _finish(
                      'A good place to pause. Score: ${_merge.score}.',
                      score: _merge.score)),
              child: const Text('Finish this round')),
        ]);
      case 'maze_trail':
        return _grid(
            6,
            List.generate(36, (i) {
              BorderSide wall(bool open) => BorderSide(
                  color: open ? Colors.transparent : AppTheme.primaryLight,
                  width: 2);
              return _tile(
                  i,
                  i == _maze.position
                      ? '●'
                      : i == 35
                          ? '⚑'
                          : '',
                  selected: i == _maze.position,
                  border: Border(
                      left: wall(_maze.paths[i].contains(i - 1)),
                      right: wall(_maze.paths[i].contains(i + 1)),
                      top: wall(_maze.paths[i].contains(i - 6)),
                      bottom: wall(_maze.paths[i].contains(i + 6))),
                  semantics:
                      'Maze cell ${i + 1}${i == _maze.position ? ', your position' : i == 35 ? ', finish' : ''}');
            }));
      case 'mine_garden':
        return Column(children: [
          FilterChip(
              label: Text(_flagging ? 'Flag mode on' : 'Reveal mode'),
              selected: _flagging,
              onSelected: (v) => setState(() => _flagging = v),
              avatar: const Icon(Icons.flag_outlined)),
          const SizedBox(height: 12),
          _grid(
              5,
              List.generate(
                  25,
                  (i) => _tile(
                      i,
                      _mine.flags.contains(i)
                          ? '⚑'
                          : _mine.lost && _mine.mines.contains(i)
                              ? '◆'
                              : _mine.open.contains(i)
                                  ? (_mine.count(i) == 0
                                      ? '·'
                                      : '${_mine.count(i)}')
                                  : '',
                      colour: _mine.open.contains(i)
                          ? const Color(0xFF245D50)
                          : null))),
          const SizedBox(height: 8),
          Text('${_mine.open.length} / 21 safe spaces'),
        ]);
      case 'mini_sudoku':
        return Column(children: [
          _grid(
              4,
              List.generate(
                  16,
                  (i) => _tile(
                      i, _sudoku.cells[i] == 0 ? '' : '${_sudoku.cells[i]}',
                      selected: _selected == i,
                      fixed: !_sudoku.blanks.contains(i),
                      colour: !_sudoku.blanks.contains(i)
                          ? const Color(0xFF343346)
                          : null))),
          const SizedBox(height: 16),
          Wrap(spacing: 10, children: [
            for (final n in [1, 2, 3, 4, 0])
              FilledButton.tonal(
                  onPressed: _finished || _selected == null
                      ? null
                      : () => setState(() {
                            _sudoku.place(_selected!, n);
                            _moves++;
                            if (_sudoku.solved)
                              _finish('Every row, column and box fits.',
                                  score: max(10, 150 - _moves));
                          }),
                  child: Text(n == 0 ? 'Clear' : '$n'))
          ]),
        ]);
      case 'word_hunt':
        return Column(children: [
          Wrap(
              spacing: 14,
              children: _word.words
                  .map((w) => Chip(
                      label: Text(w,
                          style: TextStyle(
                              decoration: _word.found.contains(w)
                                  ? TextDecoration.lineThrough
                                  : null)),
                      avatar: _word.found.contains(w)
                          ? const Icon(Icons.check, size: 16)
                          : null))
                  .toList()),
          const SizedBox(height: 12),
          _grid(
              5,
              List.generate(
                  25,
                  (i) => _tile(i, _word.cells[i],
                      selected: _selected == i,
                      colour:
                          _word.found.any((w) => _word.paths[w]!.contains(i))
                              ? const Color(0xFF245D50)
                              : null)))
        ]);
      default:
        return _quizBoard();
    }
  }

  Widget _arrows(void Function(int) move) => Column(children: [
        IconButton.filledTonal(
            tooltip: 'Move up',
            onPressed: () => move(2),
            icon: const Icon(Icons.arrow_upward)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(
              tooltip: 'Move left',
              onPressed: () => move(0),
              icon: const Icon(Icons.arrow_back)),
          const SizedBox(width: 60),
          IconButton.filledTonal(
              tooltip: 'Move right',
              onPressed: () => move(1),
              icon: const Icon(Icons.arrow_forward)),
        ]),
        IconButton.filledTonal(
            tooltip: 'Move down',
            onPressed: () => move(3),
            icon: const Icon(Icons.arrow_downward)),
      ]);
  Widget _quizBoard() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_round == 0 && _answer == null)
          Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final choice in [
                  (1, 'Gentle'),
                  (2, 'Steady'),
                  (3, 'Stretch')
                ])
                  ChoiceChip(
                    label: Text(choice.$2),
                    selected: _level == choice.$1,
                    onSelected: (_) => setState(() {
                      _level = choice.$1;
                      _question = pocketQuestion(widget.id, _random, _level);
                    }),
                  ),
              ])),
        Text('Question ${min(_round + 1, 8)} of 8 · $_correct correct',
            style: const TextStyle(color: AppTheme.primaryLight)),
        const SizedBox(height: 16),
        Text(_question.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 23, fontWeight: FontWeight.w600, height: 1.65)),
        const SizedBox(height: 24),
        for (var i = 0; i < _question.options.length; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                  onPressed: _answer != null || _finished
                      ? null
                      : () => setState(() {
                            _answer = i;
                            if (i == _question.answer) _correct++;
                            _feedback =
                                '${i == _question.answer ? 'That fits!' : 'A chance to learn.'} ${_question.explanation}';
                          }),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      side: BorderSide(
                          color: _answer != null && i == _question.answer
                              ? AppTheme.success
                              : AppTheme.border)),
                  child: Text(
                      '${_answer != null && i == _question.answer ? '✓ ' : ''}${_question.options[i]}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18)))),
        if (_answer != null && !_finished)
          FilledButton(
              onPressed: () => setState(() {
                    _round++;
                    if (_round == 8) {
                      _finish(
                          '$_correct out of 8. Take a breath; your next round can wait.',
                          score: _correct * 10);
                    } else {
                      _answer = null;
                      _feedback = '';
                      _question = pocketQuestion(widget.id, _random, _level);
                    }
                  }),
              child: Text(_round == 7 ? 'See result' : 'Next question')),
      ]);
  @override
  Widget build(BuildContext context) => GameShell(
      title: widget.title,
      subtitle: 'A short play break. Go at your pace.',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_instruction,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              height: 1.55,
                              fontSize: 15)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: Text(
                                _quiz ? 'Think it through' : '$_moves moves',
                                style: const TextStyle(fontSize: 14))),
                        TextButton.icon(
                            onPressed: () => setState(() => _paused = !_paused),
                            icon:
                                Icon(_paused ? Icons.play_arrow : Icons.pause),
                            label: Text(_paused ? 'Resume' : 'Pause'))
                      ]),
                      const SizedBox(height: 12),
                      if (_paused)
                        const Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                                'Take your time.\nYour round is waiting.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 23)))
                      else
                        _board(),
                      if (_feedback.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Semantics(
                                liveRegion: true,
                                child: Text(_feedback,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        height: 1.5,
                                        color: AppTheme.accentLight)))),
                      if (_finished) ...[
                        const SizedBox(height: 8),
                        SacredButton(
                            label: 'Another round',
                            onTap: () => setState(_reset)),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('A good place to stop'))
                      ] else
                        TextButton(
                            onPressed: () async {
                              final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                          title: const Text(
                                              'Start a fresh round?'),
                                          content: const Text(
                                              'Your current round will be replaced.'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child:
                                                    const Text('Keep playing')),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Restart'))
                                          ]));
                              if (yes == true && mounted) setState(_reset);
                            },
                            child: const Text('Restart round')),
                      const SizedBox(height: 24),
                    ]))),
      ));
}
