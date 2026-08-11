import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/journal_options.dart';
import '../core/constants/professions.dart';
import '../core/theme/app_theme.dart';
import '../models/journal_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import 'sacred.dart';
import 'voice_input_button.dart';

/// One question, asked at a random moment, filling one gap in today's entry.
///
/// The daily check-in catches people once. After that the journal only gets
/// filled if somebody deliberately opens it, and most days nobody does — so an
/// entry ends up with a mood and one line, and the analytics screen has nothing
/// to show for the month.
///
/// This closes the gap by asking, rather than waiting to be visited: whenever
/// the home screen opens, there is a chance of one small question about
/// something today's entry is still missing. One question, tappable answers,
/// dismissible, and hard-capped so it can never become nagging — see
/// [JournalNudge] for the limits.
class _QuickPromptSheet extends StatefulWidget {
  final _Slot slot;
  final JournalEntry? existing;

  const _QuickPromptSheet._({required this.slot, this.existing});

  @override
  State<_QuickPromptSheet> createState() => _QuickPromptSheetState();
}

class _QuickPromptSheetState extends State<_QuickPromptSheet> {
  final _ctrl = TextEditingController();
  final _picked = <String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _hasAnswer =>
      _picked.isNotEmpty || _ctrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final journal = context.read<JournalProvider>();
    if (auth.user == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    try {
      // Read the entry again rather than trusting the one captured when the
      // sheet opened: the user may have journalled in another tab since.
      final existing = journal.todaysEntry ?? widget.existing;
      final entry = widget.slot.apply(
        base: existing,
        uid: auth.user!.uid,
        chips: _picked.toList(),
        text: _ctrl.text.trim(),
      );
      await journal.saveEntry(entry, existingId: existing?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save that just now.',
                style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(AppTheme.space3),
          padding: const EdgeInsets.fromLTRB(AppTheme.space5, AppTheme.space4,
              AppTheme.space5, AppTheme.space5),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(slot.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: AppTheme.space2),
                  const Expanded(
                    child: Text(
                      'One quick thing',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: const Icon(Icons.close_rounded,
                        size: 19, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space3),
              Text(
                slot.prompt,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                slot.hint,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    height: 1.45,
                    color: AppTheme.textMuted),
              ),
              const SizedBox(height: AppTheme.space4),

              if (slot.options.isNotEmpty)
                Wrap(
                  spacing: AppTheme.space2,
                  runSpacing: AppTheme.space2,
                  children: slot.options.map((o) {
                    final on = _picked.contains(o.$1);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (slot.singleChoice) {
                          _picked
                            ..clear()
                            ..addAll(on ? const <String>[] : [o.$1]);
                        } else {
                          on ? _picked.remove(o.$1) : _picked.add(o.$1);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 9),
                        decoration: BoxDecoration(
                          color: on
                              ? AppTheme.primary.withValues(alpha: 0.20)
                              : Colors.white.withValues(alpha: 0.045),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPill),
                          border: Border.all(
                            color: on ? AppTheme.primary : AppTheme.border,
                            width: on ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(o.$3, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              o.$2,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12.5,
                                fontWeight:
                                    on ? FontWeight.w700 : FontWeight.w500,
                                color: on
                                    ? AppTheme.primaryLight
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              if (slot.wantsText) ...[
                if (slot.options.isNotEmpty)
                  const SizedBox(height: AppTheme.space3),
                TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: slot.writeHint,
                    hintStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: AppTheme.textMuted),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    isDense: true,
                    contentPadding: const EdgeInsets.fromLTRB(14, 13, 4, 13),
                    suffixIcon:
                        VoiceInputButton(controller: _ctrl, iconSize: 19),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.space4),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Not now',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              color: AppTheme.textMuted)),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space2),
                  Expanded(
                    flex: 2,
                    child: SacredButton(
                      label: 'Add to today',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onTap: (!_hasAnswer || _saving) ? null : _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── what can be asked ───────────────────────────

/// One askable gap in a journal entry: how to ask it, and how to write the
/// answer back without disturbing anything else on the entry.
class _Slot {
  final String id;
  final String emoji;
  final String prompt;
  final String hint;
  final List<(String, String, String)> options;
  final bool singleChoice;
  final bool wantsText;
  final String writeHint;

  /// True when today's entry has nothing recorded for this slot yet.
  final bool Function(JournalEntry? e) isEmpty;

  /// Produces the entry to save. Every field not owned by this slot is copied
  /// straight through — a nudge must never quietly erase something the member
  /// wrote in the full journal.
  final JournalEntry Function({
    required JournalEntry? base,
    required String uid,
    required List<String> chips,
    required String text,
  }) apply;

  const _Slot({
    required this.id,
    required this.emoji,
    required this.prompt,
    required this.hint,
    required this.isEmpty,
    required this.apply,
    this.options = const [],
    this.singleChoice = false,
    this.wantsText = false,
    this.writeHint = 'In your own words…',
  });
}

/// Copies [base] wholesale, overriding only what the caller names.
JournalEntry _rebuild(
  JournalEntry? b,
  String uid, {
  String? energyLevel,
  List<String>? practices,
  List<String>? influences,
  List<String>? habitsDone,
  List<String>? challenges,
  List<String>? craftDone,
  String? bestMoment,
  String? tinyStep,
  String? shivBabaLine,
  String? sleepReflection,
}) {
  return JournalEntry(
    uid: uid,
    mood: b?.mood ?? 3,
    newHabit: b?.newHabit ?? '',
    tinyStep: tinyStep ?? b?.tinyStep ?? '',
    badHabit: b?.badHabit ?? '',
    affirmations: b?.affirmations ?? '',
    visualization: b?.visualization ?? '',
    nightRoutine: b?.nightRoutine ?? '',
    triggerThought: b?.triggerThought ?? '',
    triggerResponse: b?.triggerResponse ?? '',
    bestMoment: bestMoment ?? b?.bestMoment ?? '',
    shivBabaLine: shivBabaLine ?? b?.shivBabaLine ?? '',
    sleepReflection: sleepReflection ?? b?.sleepReflection ?? '',
    energyLevel: energyLevel ?? b?.energyLevel ?? '',
    practices: practices ?? b?.practices ?? const [],
    influences: influences ?? b?.influences ?? const [],
    habitsDone: habitsDone ?? b?.habitsDone ?? const [],
    challenges: challenges ?? b?.challenges ?? const [],
    checkIn: b?.checkIn ?? const {},
    craftDone: craftDone ?? b?.craftDone ?? const [],
    craftMinutes: b?.craftMinutes ?? 0,
    createdAt: b?.createdAt ?? DateTime.now(),
  );
}

/// The craft question, which only exists once a member has named one.
///
/// Built per call rather than declared as a constant because the options are
/// this member's own habits — a singer must not be asked whether they revised
/// for an exam.
_Slot? _craftSlot(String? professionId, List<CraftHabit> customHabits) {
  if (!Professions.isKnown(professionId)) return null;
  final craft = Professions.byId(professionId);
  return _Slot(
    id: 'craft',
    emoji: craft.emoji,
    prompt: 'Any ${craft.workWord} today?',
    hint: 'Tap what you did. This is the one that builds your streak.',
    options: [
      for (final h in Professions.checklistFor(professionId, customHabits))
        (h.id, h.label, h.emoji),
    ],
    isEmpty: (e) => (e?.craftDone ?? const []).isEmpty,
    apply: ({base, required uid, required chips, required text}) =>
        _rebuild(base, uid, craftDone: chips),
  );
}

final _slots = <_Slot>[
  _Slot(
    id: 'energy',
    emoji: '🔋',
    prompt: 'How is your energy right now?',
    hint: 'One tap. It goes straight into today.',
    options: JournalOptions.energyLevels,
    singleChoice: true,
    isEmpty: (e) => (e?.energyLevel ?? '').isEmpty,
    apply: ({base, required uid, required chips, required text}) => _rebuild(
        base, uid,
        energyLevel: chips.isEmpty ? '' : chips.first),
  ),
  _Slot(
    id: 'practices',
    emoji: '🧘',
    prompt: 'Done any of these today?',
    hint: 'Tap any that apply. Nothing counts as an answer too.',
    options: JournalOptions.practices,
    isEmpty: (e) => (e?.practices ?? const []).isEmpty,
    apply: ({base, required uid, required chips, required text}) =>
        _rebuild(base, uid, practices: chips),
  ),
  _Slot(
    id: 'influences',
    emoji: '🌊',
    prompt: 'What has been shaping today?',
    hint: 'Whatever has taken up the most room in your head.',
    options: JournalOptions.influences,
    isEmpty: (e) => (e?.influences ?? const []).isEmpty,
    apply: ({base, required uid, required chips, required text}) =>
        _rebuild(base, uid, influences: chips),
  ),
  _Slot(
    id: 'habits',
    emoji: '✅',
    prompt: 'Anything go right today?',
    hint: 'Small things count. They are mostly what there is.',
    options: JournalOptions.habits,
    isEmpty: (e) => (e?.habitsDone ?? const []).isEmpty,
    apply: ({base, required uid, required chips, required text}) =>
        _rebuild(base, uid, habitsDone: chips),
  ),
  _Slot(
    id: 'challenges',
    emoji: '🌀',
    prompt: 'Anything pulling at you?',
    hint: 'Naming it is the whole exercise. You do not have to fix it.',
    options: JournalOptions.challenges,
    isEmpty: (e) => (e?.challenges ?? const []).isEmpty,
    apply: ({base, required uid, required chips, required text}) =>
        _rebuild(base, uid, challenges: chips),
  ),
  _Slot(
    id: 'line',
    emoji: '✍️',
    prompt: 'Say one line about today',
    hint: 'Type it, or tap the mic and speak it.',
    wantsText: true,
    writeHint: 'Anything at all. One sentence is enough.',
    isEmpty: (e) => (e?.bestMoment ?? '').trim().isEmpty,
    apply: ({base, required uid, required chips, required text}) =>
        _rebuild(base, uid, bestMoment: text),
  ),
  _Slot(
    id: 'tiny_step',
    emoji: '👣',
    prompt: 'What is one small thing you did today?',
    hint: 'It does not have to be impressive. It has to be true.',
    wantsText: true,
    writeHint: 'One small step…',
    isEmpty: (e) => (e?.tinyStep ?? '').trim().isEmpty,
    apply: ({base, required uid, required chips, required text}) =>
        _rebuild(base, uid, tinyStep: text),
  ),
  _Slot(
    id: 'line_kept',
    emoji: '📖',
    prompt: 'Read or heard anything worth keeping?',
    hint: 'A line from a book, a talk, a song, a person.',
    wantsText: true,
    writeHint: 'The line that stayed with you…',
    isEmpty: (e) => (e?.shivBabaLine ?? '').trim().isEmpty,
    apply: ({base, required uid, required chips, required text}) =>
        _rebuild(base, uid, shivBabaLine: text),
  ),
  _Slot(
    id: 'sleep',
    emoji: '😴',
    prompt: 'How did you sleep last night?',
    hint: 'Sleep explains more of a mood than anything else does.',
    wantsText: true,
    writeHint: 'Well, badly, dreams, none of it…',
    isEmpty: (e) => (e?.sleepReflection ?? '').trim().isEmpty,
    apply: ({base, required uid, required chips, required text}) =>
        _rebuild(base, uid, sleepReflection: text),
  ),
];

// ─────────────────────────── when to ask ───────────────────────────

/// Decides whether to interrupt, and with what.
///
/// The limits are the feature. An app that asks a question every time it opens
/// is uninstalled by the end of the week, so:
///   • at most [_maxPerDay] prompts in a day, ever;
///   • at least [_minGap] between two of them;
///   • never within the first [_graceAfterCheckIn] of the daily check-in;
///   • and even when all of that passes, only a [_chance] probability — so the
///     prompt does not become a predictable toll booth on the home screen.
///
/// Only gaps are asked about, so a member who has filled everything in is never
/// interrupted at all.
class JournalNudge {
  static const _maxPerDay = 3;
  static const _minGap = Duration(minutes: 40);
  static const _graceAfterCheckIn = Duration(minutes: 20);
  static const _chance = 0.55;

  /// The day's first prompt is not left to chance.
  ///
  /// A purely random nudge means somebody who opens the app once a day has a
  /// 45% chance of never being asked anything — and the whole point is that the
  /// journal keeps filling itself in. So the first one each day is certain; the
  /// second and third are the ones that roll a die, which is what keeps it
  /// feeling like a conversation rather than a toll booth.
  static bool _isFirstOfDay(int shownToday) => shownToday == 0;

  static String get _todayKey =>
      DateTime.now().toIso8601String().substring(0, 10);

  /// Recorded by the check-in so a nudge cannot land straight after it.
  static Future<void> markCheckInShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'checkin_shown_at', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> maybeShow(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return false;

    final prefs = await SharedPreferences.getInstance();

    final shownToday = prefs.getInt('nudge_count_$_todayKey') ?? 0;
    if (shownToday >= _maxPerDay) return false;

    final lastMs = prefs.getInt('nudge_last_at') ?? 0;
    final since = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastMs));
    if (since < _minGap) return false;

    final checkInMs = prefs.getInt('checkin_shown_at') ?? 0;
    if (checkInMs > 0) {
      final sinceCheckIn = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(checkInMs));
      if (sinceCheckIn < _graceAfterCheckIn) return false;
    }

    if (!_isFirstOfDay(shownToday) && Random().nextDouble() > _chance) {
      return false;
    }

    if (!context.mounted) return false;
    final journal = context.read<JournalProvider>();
    final today = journal.todaysEntry;
    final profile = context.read<AuthProvider>().profile;

    // Ask about a gap, chosen at random among the gaps so the same question
    // does not arrive three days running.
    final craft = _craftSlot(
        profile?.profession, profile?.customHabits ?? const []);
    final candidates = <_Slot>[
      // Twice in the pool on purpose: the craft question is the one that feeds
      // the consistency chart, so it deserves roughly double the odds of a
      // question about last night's sleep.
      if (craft != null) ...[craft, craft],
      ..._slots,
    ];
    final open = candidates.where((s) => s.isEmpty(today)).toList();
    if (open.isEmpty) return false;
    final slot = open[Random().nextInt(open.length)];

    await prefs.setInt('nudge_count_$_todayKey', shownToday + 1);
    await prefs.setInt('nudge_last_at', DateTime.now().millisecondsSinceEpoch);

    if (!context.mounted) return false;
    final answered = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickPromptSheet._(slot: slot, existing: today),
    );
    return answered == true;
  }
}
