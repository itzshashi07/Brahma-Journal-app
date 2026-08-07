import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/checkin_questions.dart';
import '../../core/theme/app_theme.dart';
import '../../models/journal_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../widgets/sacred.dart';

/// The daily check-in, shown once a day after opening the app.
///
/// Deliberately a conversation rather than a form: one question on screen at a
/// time, every one skippable, and the app responds to the mood rather than
/// silently recording it. Someone who says today was heavy should not be met
/// with a progress bar.
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
  final _answers = <String, String>{};
  final _controller = TextEditingController();
  final _pageController = PageController();

  int? _mood;
  int _step = -1; // -1 is the mood step
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  CheckInQuestion get _question => _questions[_step];

  void _next({bool skipped = false}) {
    if (_step >= 0 && !skipped) {
      final text = _controller.text.trim();
      if (text.isNotEmpty) _answers[_question.id] = text;
    }
    _controller.clear();

    if (_step + 1 >= _questions.length) {
      _finish();
      return;
    }
    setState(() => _step++);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final journal = context.read<JournalProvider>();
    if (auth.user == null) {
      if (mounted) Navigator.pop(context, false);
      return;
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
        bestMoment: _answers['exciting'] ?? existing?.bestMoment ?? '',
        shivBabaLine: existing?.shivBabaLine ?? '',
        sleepReflection: existing?.sleepReflection ?? '',
        energyLevel: existing?.energyLevel ?? '',
        practices: existing?.practices ?? const [],
        influences: existing?.influences ?? const [],
        habitsDone: existing?.habitsDone ?? const [],
        challenges: existing?.challenges ?? const [],
        checkIn: _answers,
        createdAt: existing?.createdAt ?? DateTime.now(),
      );

      await journal.saveEntry(entry, existingId: existing?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
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

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.all(AppTheme.space3),
        padding: const EdgeInsets.all(AppTheme.space5),
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
            const SizedBox(height: AppTheme.space5),
            if (_step < 0) _moodStep() else _questionStep(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── mood ───────────────────────────

  Widget _moodStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Motif(SacredMotif.lotus, size: 26, color: AppTheme.primaryLight),
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
            return GestureDetector(
              onTap: () => setState(() => _mood = m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: AppTheme.space3),
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
                    Text(m.$3, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      m.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 9.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        color: selected
                            ? AppTheme.primaryLight
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
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
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
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

        const SizedBox(height: AppTheme.space5),
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
    );
  }

  // ─────────────────────────── questions ───────────────────────────

  Widget _questionStep() {
    final q = _question;
    final progress = (_step + 1) / _questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(q.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: AppTheme.space2),
            Text(
              '${_step + 1} of ${_questions.length}',
              style: const TextStyle(
                  fontFamily: 'Outfit', fontSize: 11.5, color: AppTheme.textMuted),
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

        TextField(
          controller: _controller,
          maxLines: 4,
          autofocus: false,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
              fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Say as much or as little as you like…',
            hintStyle: const TextStyle(
                fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: AppTheme.space4),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _saving ? null : () => _next(skipped: true),
                child: Text(q.skipLabel,
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
                label: _step + 1 >= _questions.length ? 'Finish' : 'Next',
                icon: _step + 1 >= _questions.length
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
}
