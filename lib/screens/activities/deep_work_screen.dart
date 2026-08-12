import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/professions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/stats_utils.dart';
import '../../models/journal_entry.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../services/profile_service.dart';
import '../../widgets/craft_setup_sheet.dart';
import '../../widgets/sacred.dart';

/// Deep work: the plan, and whether it is actually happening.
///
/// ─────────────────────────────────────────────────────────────────────────
/// What this adds to naming a profession
///
/// Choosing a craft gave a member a row of chips on the journal: tap what you
/// did today. That is enough to *record* the work and not nearly enough to run
/// it. Two things were missing, and they are the two things anybody trying to
/// get good at something actually wants:
///
///   1. **A plan of their own.** The preset habits under each profession are a
///      starting point written by somebody who has never met them. "Riyaaz",
///      "revision", "one hard thing" — fine, and not the same as *my* plan for
///      this month. So the list is theirs to write: add a step, rename it,
///      drop it when it stops being the work.
///   2. **A daily answer.** A chip you ticked yesterday tells you nothing. What
///      tells you something is fourteen dots in a row — how many you filled,
///      where the gap is, how long the current run has lasted. That is the
///      picture people come back to check, and it is the reason this is a
///      screen rather than another card.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Where the data lives — nothing new was invented
///
/// The plan items are `profile.customHabits`, which the setup sheet has always
/// written. Ticking one writes to today's journal entry's `craftDone`, exactly
/// as the chips on the journal do — so a step ticked here shows as ticked
/// there, counts towards the consistency chart, and is one number in analytics
/// rather than two that disagree. There is no second store and no second
/// definition of "done today".
///
/// The dots are read from the entries the [JournalProvider] already holds, by
/// **local** calendar day. See `dayMarker` in core/utils/stats_utils.dart for
/// why that word is load-bearing.
class DeepWorkScreen extends StatefulWidget {
  const DeepWorkScreen({super.key});

  @override
  State<DeepWorkScreen> createState() => _DeepWorkScreenState();
}

class _DeepWorkScreenState extends State<DeepWorkScreen> {
  final _profiles = ProfileService();
  final _newItemCtrl = TextEditingController();

  /// Ids being written right now, so a second tap on the same row is ignored
  /// rather than racing the first.
  final Set<String> _busy = {};
  bool _addingItem = false;

  /// How many days the strip shows. Two weeks is the shortest window in which
  /// a pattern is visible and the longest that fits on a phone without the
  /// dots becoming decoration.
  static const _windowDays = 14;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _newItemCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    await context.read<JournalProvider>().loadEntries(uid);
  }

  /// Ticks or unticks one step for today.
  ///
  /// Writes through the journal, because that is where "what I did today"
  /// lives. An entry for today is created if there is not one yet — a member
  /// who opens this screen and ticks a step has journalled by any reasonable
  /// definition, and refusing to record it until they also filled in a mood
  /// would be the app being precious about its own form.
  Future<void> _toggle(String habitId) async {
    final auth = context.read<AuthProvider>();
    final journal = context.read<JournalProvider>();
    final uid = auth.user?.uid;
    if (uid == null || _busy.contains(habitId)) return;

    setState(() => _busy.add(habitId));

    try {
      final today = journal.todaysEntry;
      final done = {...(today?.craftDone ?? const <String>[])};
      done.contains(habitId) ? done.remove(habitId) : done.add(habitId);

      final entry = (today ??
              JournalEntry(
                uid: uid,
                mood: 3,
                createdAt: DateTime.now(),
              ))
          .copyWith(craftDone: done.toList());

      await journal.saveEntry(entry, existingId: today?.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save that. Try again in a moment.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(habitId));
    }
  }

  /// Adds a step the member wrote themselves.
  Future<void> _addItem(UserProfile profile) async {
    final label = _newItemCtrl.text.trim();
    if (label.isEmpty || _addingItem) return;

    final custom = List<CraftHabit>.of(profile.customHabits);
    if (custom.length >= Professions.maxCustomHabits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'That is ${Professions.maxCustomHabits} steps — enough for a plan. Remove one first.',
              style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    // Same label twice is a mistake rather than an intention: two identical
    // rows tick independently and the strip stops meaning anything.
    if (custom.any((h) => h.label.toLowerCase() == label.toLowerCase())) {
      _newItemCtrl.clear();
      return;
    }

    setState(() => _addingItem = true);
    try {
      custom.add(CraftHabit.custom(label: label));
      await _profiles.saveProfile(profile.copyWith(customHabits: custom));
      await context.read<AuthProvider>().refreshProfile();
      _newItemCtrl.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add that step.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _addingItem = false);
    }
  }

  /// Removes one of the member's own steps.
  ///
  /// The history stays. A step dropped in March should not rewrite February —
  /// the ticks live on the entries, and this only stops asking about it.
  Future<void> _removeItem(UserProfile profile, CraftHabit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove this step?',
            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: Text(
          '"${habit.label}" comes off your plan. The days you already ticked stay '
          'in your history.',
          style: const TextStyle(
              fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep it', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Remove',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final custom =
        profile.customHabits.where((h) => h.id != habit.id).toList();
    await _profiles.saveProfile(profile.copyWith(customHabits: custom));
    if (mounted) await context.read<AuthProvider>().refreshProfile();
  }

  // ─────────────────────────── the numbers ───────────────────────────

  /// The last [_windowDays] local days, oldest first.
  List<DateTime> get _window {
    final today = todayMarker();
    return List.generate(
      _windowDays,
      (i) => today.subtract(Duration(days: _windowDays - 1 - i)),
    );
  }

  /// Which days each step was ticked on, as day markers.
  Map<String, Set<DateTime>> _historyFor(List<JournalEntry> entries) {
    final history = <String, Set<DateTime>>{};
    for (final entry in entries) {
      final day = dayMarker(entry.createdAt);
      for (final id in entry.craftDone) {
        history.putIfAbsent(id, () => <DateTime>{}).add(day);
      }
    }
    return history;
  }

  /// Consecutive days ending today or yesterday. The same rule as the journal
  /// streak, so the two numbers cannot disagree.
  int _runFor(Set<DateTime> days) => streakFromDates(days);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final journal = context.watch<JournalProvider>();
    final profile = auth.profile;

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: profile == null
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary))
                    : !profile.hasCraft
                        ? _needsSetup()
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppTheme.primary,
                            backgroundColor: AppTheme.bgCard,
                            child: _plan(profile, journal),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: AppTheme.textPrimary, size: 20),
              onPressed: () => context.pop(),
            ),
            const Expanded(
              child: Column(
                children: [
                  Text('Deep work',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  Text('Your plan, and whether it is happening',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          color: AppTheme.textMuted)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded,
                  color: AppTheme.textMuted, size: 20),
              tooltip: 'Craft settings',
              onPressed: () async {
                final done = await CraftSetupSheet.show(context);
                if (done == true && mounted) setState(() {});
              },
            ),
          ],
        ),
      );

  Widget _needsSetup() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎯', style: TextStyle(fontSize: 34)),
              const SizedBox(height: 14),
              const Text(
                'Name the thing first',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Singing, studying, building something. Once it has a name, this '
                'screen becomes your plan for it — steps you write yourself, '
                'ticked daily, with the last fortnight in a row of dots.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    height: 1.6,
                    color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              SacredButton(
                label: 'Set it up — 20 seconds',
                icon: Icons.arrow_forward_rounded,
                onTap: () async {
                  final done = await CraftSetupSheet.show(context);
                  if (done == true && mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      );

  Widget _plan(UserProfile profile, JournalProvider journal) {
    final craft = Professions.byId(profile.profession);
    final accent = Professions.accentFor(craft.id);
    final history = _historyFor(journal.entries);
    final todayDone = {...(journal.todaysEntry?.craftDone ?? const <String>[])};
    final checklist = profile.checklist;

    // Today's score, said plainly at the top. "3 of 6" is the one number
    // somebody opens this screen for.
    final doneToday = checklist.where((h) => todayDone.contains(h.id)).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _todayCard(craft, accent, doneToday, checklist.length, profile),
        const SizedBox(height: 18),
        Text(
          'Your plan',
          style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          'Tap a step to tick it for today. The dots are the last fortnight — '
          'filled means done.',
          style: const TextStyle(
              fontFamily: 'Outfit', fontSize: 11.5, height: 1.5, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 12),
        ...checklist.map((habit) => _stepRow(
              habit: habit,
              accent: accent,
              done: todayDone.contains(habit.id),
              days: history[habit.id] ?? const <DateTime>{},
              profile: profile,
            )),
        const SizedBox(height: 8),
        _addRow(profile),
      ],
    );
  }

  Widget _todayCard(Profession craft, Color accent, int done, int total,
          UserProfile profile) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
        ),
        child: Row(
          children: [
            Text(craft.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (profile.aim ?? '').isEmpty
                        ? 'Your ${craft.workWord}'
                        : profile.aim!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    total == 0
                        ? 'No steps yet — write the first one below.'
                        : done == 0
                            ? 'Nothing ticked today. One is enough to keep the run.'
                            : '$done of $total done today.',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (total > 0)
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                    Text('$done',
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _stepRow({
    required CraftHabit habit,
    required Color accent,
    required bool done,
    required Set<DateTime> days,
    required UserProfile profile,
  }) {
    final run = _runFor(days);
    final thisWeek = days
        .where((d) => todayMarker().difference(d).inDays < 7)
        .length;
    final working = _busy.contains(habit.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: done ? accent.withValues(alpha: 0.10) : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: done ? accent.withValues(alpha: 0.45) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The tick target is the whole left side, not a 20px box — this
              // is tapped every day and often one-handed.
              Expanded(
                child: InkWell(
                  onTap: working ? null : () => _toggle(habit.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: done ? accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: done ? accent : AppTheme.textMuted, width: 1.6),
                        ),
                        child: working
                            ? const Padding(
                                padding: EdgeInsets.all(4),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : done
                                ? const Icon(Icons.check_rounded,
                                    size: 16, color: Colors.white)
                                : null,
                      ),
                      const SizedBox(width: 11),
                      Text(habit.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          habit.label,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Only the member's own steps can be removed. A preset belongs to
              // the profession and comes back when it is reselected, so a
              // delete on it would be a button that does not stay done.
              if (habit.isCustom)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 17, color: AppTheme.textMuted),
                  tooltip: 'Remove from my plan',
                  onPressed: () => _removeItem(profile, habit),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ..._window.map((day) {
                final filled = days.contains(day);
                final isToday = day == todayMarker();
                return Container(
                  width: 13,
                  height: 13,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: filled ? accent : Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                    border: isToday
                        ? Border.all(color: AppTheme.textSecondary, width: 1.2)
                        : null,
                  ),
                );
              }),
              const Spacer(),
              Text(
                run > 0 ? '$run day${run == 1 ? '' : 's'} running' : '$thisWeek this week',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: run > 0 ? accent : AppTheme.textMuted),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addRow(UserProfile profile) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: _newItemCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addItem(profile),
              maxLength: 60,
              style: const TextStyle(
                  fontFamily: 'Outfit', fontSize: 13.5, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Add a step — "two hours, phone in another room"',
                hintStyle: const TextStyle(
                    fontFamily: 'Outfit', fontSize: 12.5, color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.bgCard,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _addingItem ? null : () => _addItem(profile),
            style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
            icon: _addingItem
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ],
      );
}
