import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/checkin_questions.dart';
import '../../core/theme/app_theme.dart';
import '../../models/journal_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../widgets/sacred.dart';
import '../../widgets/voice_input_button.dart';

/// The daily check-in, shown once a day after opening the app.
///
/// Deliberately a conversation rather than a form: one question on screen at a
/// time, every one skippable, and the app responds to the mood rather than
/// silently recording it. Someone who says today was heavy should not be met
/// with a progress bar.
///
/// Every question can be answered by tapping. That is the change that decides
/// whether this gets used at all — an empty text box asks for an essay, and at
/// the end of a long day the honest response to an essay is to close the sheet.
/// Chips take a second, mean something, and are still stored as real answers.
/// Underneath them the keyboard and microphone stay available for anyone who
/// does want to say more.
///
/// Completing it writes today's journal entry, so the check-in feeds the same
/// streak, analytics and leaderboard as the full journal. Two paths to the same
/// record rather than two records that can disagree.
class DailyCheckInSheet extends StatefulWidget {
  const DailyCheckInSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Dismissible: a check-in you cannot escape is an interrogation.
      isDismissible: true,
      enableDrag: true,
      builder: (_) => const DailyCheckInSheet(),
    );
  }

  @override
  State<DailyCheckInSheet> createState() => _DailyCheckInSheetState();
}

class _DailyCheckInSheetState extends State<DailyCheckInSheet> {
  final _questions = CheckInQuestions.forToday();

  /// Free text per question id, kept alive between steps so going back does not
  /// lose what was already typed or spoken.
  final _typed = <String, TextEditingController>{};

  /// Chips tapped per question id, in tap order.
  final _picked = <String, Set<String>>{};

  int? _mood;
  int _step = -1; // -1 is the mood step, _questions.length is the closing card
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    for (final q in _questions) {
      // Listened to rather than watched through onChanged: dictation writes
      // straight into the controller, and the answered-count would otherwise
      // never notice a spoken answer.
      _typed[q.id] = TextEditingController()
        ..addListener(() {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    for (final c in _typed.values) {
      c.dispose();
    }
    super.dispose();
  }

  CheckInQuestion get _question => _questions[_step];

  bool get _onClosingCard => _step >= _questions.length;

  /// A question counts as answered if anything was tapped or written.
  String? _answerFor(CheckInQuestion q) {
    final chips = _picked[q.id] ?? const <String>{};
    final written = _typed[q.id]?.text.trim() ?? '';
    if (chips.isEmpty && written.isEmpty) return null;
    if (chips.isEmpty) return written;
    if (written.isEmpty) return chips.join(', ');
    return '${chips.join(', ')} — $written';
  }

  int get _answeredCount =>
      _questions.where((q) => _answerFor(q) != null).length;

  void _toggleChip(CheckInQuestion q, String option) {
    setState(() {
      final current = _picked.putIfAbsent(q.id, () => <String>{});
      final alreadyPicked = current.contains(option);
      if (q.isMultiSelect) {
        alreadyPicked ? current.remove(option) : current.add(option);
      } else {
        // Tapping the selected answer again clears it — the way out of an
        // answer you did not mean to give.
        current.clear();
        if (!alreadyPicked) current.add(option);
      }
    });
  }

  void _next({bool skipped = false}) {
    if (skipped) {
      _picked.remove(_question.id);
      _typed[_question.id]?.clear();
    }
    if (_step + 1 >= _questions.length) {
      setState(() => _step = _questions.length);
      _finish();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() => _step--);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final journal = context.read<JournalProvider>();
    if (auth.user == null) {
      if (mounted) Navigator.pop(context, false);
      return;
    }

    final answers = <String, String>{};
    for (final q in _questions) {
      final a = _answerFor(q);
      if (a != null) answers[q.id] = a;
    }

    try {
      // Merge into today's entry rather than creating a second record, so a
      // member who also writes a full journal entry does not end up with two.
      final existing = journal.todaysEntry;
      final entry = JournalEntry(
        uid: auth.user!.uid,
        mood: _mood ?? existing?.mood ?? 3,
        newHabit: existing?.newHabit ?? '',
        tinyStep: existing?.tinyStep ?? '',
        badHabit: existing?.badHabit ?? '',
        affirmations: existing?.affirmations ?? '',
        visualization: existing?.visualization ?? '',
        nightRoutine: existing?.nightRoutine ?? '',
        triggerThought: existing?.triggerThought ?? '',
        triggerResponse: existing?.triggerResponse ?? '',
        bestMoment: answers['exciting'] ?? existing?.bestMoment ?? '',
        shivBabaLine: existing?.shivBabaLine ?? '',
        sleepReflection: existing?.sleepReflection ?? '',
        energyLevel: existing?.energyLevel ?? '',
        practices: existing?.practices ?? const [],
        influences: existing?.influences ?? const [],
        habitsDone: existing?.habitsDone ?? const [],
        challenges: existing?.challenges ?? const [],
        checkIn: {...?existing?.checkIn, ...answers},
        createdAt: existing?.createdAt ?? DateTime.now(),
      );

      await journal.saveEntry(entry, existingId: existing?.id);
      if (mounted) setState(() => _saving = false);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) {
        // Back to the last question rather than stranding them on a card with
        // nothing to press — their answers are all still in memory.
        setState(() {
          _saving = false;
          _step = _questions.length - 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Your answers are still here.',
                style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.86;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            margin: const EdgeInsets.all(AppTheme.space3),
            padding: const EdgeInsets.fromLTRB(AppTheme.space5, AppTheme.space4,
                AppTheme.space5, AppTheme.space5),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.shadowSoft,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _onClosingCard
                          ? _closingCard()
                          : (_step < 0 ? _moodStep() : _questionStep()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── mood ───────────────────────────

  Widget _moodStep() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Motif(SacredMotif.lotus,
                  size: 26, color: AppTheme.primaryLight),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Let us talk',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Nobody else sees this. Not one word.',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        color: AppTheme.textMuted.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          const Text(
            'How are you feeling today?',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: CheckInMoods.options.map((m) {
              final selected = _mood == m.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mood = m.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppTheme.space3),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withValues(alpha: 0.20)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.border,
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(m.$3, style: const TextStyle(fontSize: 23)),
                        const SizedBox(height: 4),
                        Text(
                          m.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 9.5,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w400,
                            color: selected
                                ? AppTheme.primaryLight
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // The app answers rather than only collecting. A low mood met with
          // silence is worse than not asking.
          if (_mood != null) ...[
            const SizedBox(height: AppTheme.space4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                CheckInMoods.responseFor(_mood!),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppTheme.space4),
          Row(
            children: [
              const Icon(Icons.touch_app_outlined,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_questions.length} short questions. Tap your answers — typing is optional.',
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11.5,
                      color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Not now',
                      style: TextStyle(
                          fontFamily: 'Outfit', color: AppTheme.textMuted)),
                ),
              ),
              const SizedBox(width: AppTheme.space2),
              Expanded(
                flex: 2,
                child: SacredButton(
                  label: 'Start',
                  icon: Icons.arrow_forward_rounded,
                  onTap: _mood == null ? null : () => setState(() => _step = 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── questions ───────────────────────────

  Widget _questionStep() {
    final q = _question;
    final progress = (_step + 1) / _questions.length;
    final answered = _answerFor(q) != null;
    final isLast = _step + 1 >= _questions.length;
    // Skipping and moving on are the same action once something is answered;
    // labelling both "skip" would suggest the answer is about to be thrown away.
    final secondaryLabel = answered ? 'Clear' : q.skipLabel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_step > 0)
              GestureDetector(
                onTap: _back,
                child: const Padding(
                  padding: EdgeInsets.only(right: AppTheme.space2),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 18, color: AppTheme.textMuted),
                ),
              ),
            Text(q.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: AppTheme.space2),
            Text(
              '${_step + 1} of ${_questions.length}',
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  color: AppTheme.textMuted),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: const Icon(Icons.close_rounded,
                  size: 20, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: Colors.white.withValues(alpha: 0.07),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
        const SizedBox(height: AppTheme.space5),

        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.prompt,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 19,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.space2),
                Text(
                  q.hint,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),

                if (q.options.isNotEmpty) ...[
                  if (q.isMultiSelect)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.space2),
                      child: Text(
                        'Tap as many as apply',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: AppTheme.textMuted),
                      ),
                    ),
                  Wrap(
                    spacing: AppTheme.space2,
                    runSpacing: AppTheme.space2,
                    children: q.options
                        .map((o) => _AnswerChip(
                              label: o,
                              selected:
                                  _picked[q.id]?.contains(o) ?? false,
                              onTap: () => _toggleChip(q, o),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppTheme.space4),
                ],

                // The written answer. For a spoken question it is the whole
                // point, so it opens tall with the microphone beside it; under
                // chips it is a quieter follow-up.
                _WriteBox(
                  controller: _typed[q.id]!,
                  hint: q.writeHint,
                  lines: q.isSpoken ? 4 : 2,
                  emphasised: q.isSpoken,
                  onChanged: () => setState(() {}),
                ),
                if (q.isSpoken) ...[
                  const SizedBox(height: AppTheme.space2),
                  Row(
                    children: [
                      const Icon(Icons.graphic_eq_rounded,
                          size: 13, color: AppTheme.primaryLight),
                      const SizedBox(width: 6),
                      Text(
                        'Tap the mic and speak — it writes itself down.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          color: AppTheme.primaryLight.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: AppTheme.space4),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () => answered
                        ? setState(() {
                            _picked.remove(q.id);
                            _typed[q.id]?.clear();
                          })
                        : _next(skipped: true),
                child: Text(secondaryLabel,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: AppTheme.textMuted)),
              ),
            ),
            const SizedBox(width: AppTheme.space2),
            Expanded(
              flex: 2,
              child: SacredButton(
                label: isLast ? 'Finish' : 'Next',
                icon: isLast
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                loading: _saving,
                onTap: _saving ? null : () => _next(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────── closing ───────────────────────────

  /// The check-in ends with a sentence, not a disappearing sheet. Someone who
  /// just told the app about a hard day deserves to be answered before it
  /// closes on them.
  Widget _closingCard() {
    if (!_saved) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.space10),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: AppTheme.space4),
              Text('Keeping this safe…',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Motif(SacredMotif.lotus, size: 26, color: AppTheme.accent),
            SizedBox(width: AppTheme.space3),
            Expanded(
              child: Text(
                'Written down.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space3),
        Text(
          CheckInMoods.farewellFor(_mood ?? 3),
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13.5,
            height: 1.55,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space3),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 16, color: AppTheme.success),
              const SizedBox(width: AppTheme.space2),
              Expanded(
                child: Text(
                  '$_answeredCount of ${_questions.length} answered · today\'s entry saved',
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space5),
        SacredButton(
          label: 'Done',
          icon: Icons.check_rounded,
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

/// A tappable answer. Large enough to hit without aiming, and it reads as an
/// answer rather than a filter.
class _AnswerChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded,
                  size: 14, color: AppTheme.primaryLight),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color:
                    selected ? AppTheme.primaryLight : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The write-or-speak box under every question.
class _WriteBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int lines;
  final bool emphasised;
  final VoidCallback onChanged;

  const _WriteBox({
    required this.controller,
    required this.hint,
    required this.lines,
    required this.emphasised,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: lines,
      minLines: 1,
      autofocus: false,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => onChanged(),
      style: const TextStyle(
          fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
        suffixIcon: VoiceInputButton(controller: controller, iconSize: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(
            color: emphasised
                ? AppTheme.primary.withValues(alpha: 0.45)
                : AppTheme.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
