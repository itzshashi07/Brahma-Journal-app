import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/professions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/stats_utils.dart';
import '../../models/journal_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../services/milestone_service.dart';
import '../../widgets/craft_setup_sheet.dart';
import '../../widgets/sacred.dart';

/// Deep work: one milestone, the steps under it, and whether it is on course.
///
/// ─────────────────────────────────────────────────────────────────────────
/// The order is the feature
///
/// **Milestone first.** Everything else this app measures is a habit — did you
/// sit, did you write, did you practise. Habits are the right unit for a streak
/// and the wrong unit for work that is going somewhere: "practised forty days
/// running" says nothing about whether the album exists. So the first question
/// here is not "what will you do today", it is *what are you trying to finish*,
/// and by when.
///
/// **Then the member's own todos.** The suggestions are seeded from their
/// craft, and every one of them can be deleted; a list somebody else wrote is a
/// list nobody does. Add, tick, remove — nothing else, because anything more is
/// project management and this is meant to be opened for thirty seconds.
///
/// **Then the analysis, and it has to be honest.** Percentage done, what is
/// left, days remaining, how many days of actual deep work went in over the
/// last fortnight, and — the number people avoid — whether the current pace
/// reaches the target date. An app that only ever says "great job" is one
/// nobody believes the third time.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Where the numbers come from
///
/// The milestone and its todos are their own record (`/api/practice/milestones`
/// — see models/Practice.js for why they are not habits). The *days worked* are
/// the journal's, read from `craftDone` on each entry by local calendar day, so
/// this screen and the consistency chart cannot disagree about what a day of
/// deep work was. Ticking the daily practice here writes the same field the
/// journal's chips write.
class DeepWorkScreen extends StatefulWidget {
  const DeepWorkScreen({super.key});

  @override
  State<DeepWorkScreen> createState() => _DeepWorkScreenState();
}

class _DeepWorkScreenState extends State<DeepWorkScreen> {
  final _milestones = MilestoneService();
  final _todoCtrl = TextEditingController();

  Milestone? _milestone;
  bool _loading = true;
  String? _error;

  /// Ids being written right now, so a second tap is ignored rather than racing
  /// the first.
  final Set<String> _busy = {};

  static const _windowDays = 14;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _todoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?.uid;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final all = await _milestones.all();
      if (uid != null && mounted) {
        // The entries back the "days worked" half of the analysis.
        await context.read<JournalProvider>().loadEntries(uid);
      }
      if (!mounted) return;
      setState(() {
        _milestone = all.where((m) => m.isActive).isEmpty
            ? null
            : all.firstWhere((m) => m.isActive);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // ─────────────────────────── writes ───────────────────────────

  Future<void> _saveTodos(List<MilestoneTodo> todos) async {
    final current = _milestone;
    if (current == null) return;

    // Optimistic: the list is what the member just did, and a checkbox that
    // waits for a round trip gets tapped twice.
    setState(() => _milestone = current.copyWith(todos: todos));

    try {
      final saved = await _milestones.update(current.id, todos: todos);
      if (mounted) setState(() => _milestone = saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _milestone = current);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save that. Try again in a moment.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _toggleTodo(MilestoneTodo todo) async {
    if (_busy.contains(todo.id)) return;
    setState(() => _busy.add(todo.id));

    final next = _milestone!.todos
        .map((t) => t.id == todo.id
            ? t.copyWith(done: !t.done, doneAt: DateTime.now())
            : t)
        .toList();

    await _saveTodos(next);
    if (mounted) setState(() => _busy.remove(todo.id));
  }

  Future<void> _addTodo() async {
    final label = _todoCtrl.text.trim();
    if (label.isEmpty || _milestone == null) return;

    if (_milestone!.todos.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fifty steps is a project, not a milestone. Finish some first.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    _todoCtrl.clear();
    FocusScope.of(context).unfocus();
    await _saveTodos([..._milestone!.todos, MilestoneTodo.create(label)]);
  }

  Future<void> _removeTodo(MilestoneTodo todo) async {
    await _saveTodos(
        _milestone!.todos.where((t) => t.id != todo.id).toList());
  }

  /// Ticks today's deep work in the journal, which is what the days-worked
  /// half of the analysis counts.
  Future<void> _markWorkedToday() async {
    final auth = context.read<AuthProvider>();
    final journal = context.read<JournalProvider>();
    final uid = auth.user?.uid;
    if (uid == null || _busy.contains('_today')) return;

    setState(() => _busy.add('_today'));
    try {
      final today = journal.todaysEntry;
      final done = {...(today?.craftDone ?? const <String>[])};
      const id = 'deep_work';
      done.contains(id) ? done.remove(id) : done.add(id);

      final entry =
          (today ?? JournalEntry(uid: uid, mood: 3, createdAt: DateTime.now()))
              .copyWith(craftDone: done.toList());

      await journal.saveEntry(entry, existingId: today?.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not record that.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove('_today'));
    }
  }

  Future<void> _finish() async {
    final current = _milestone;
    if (current == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Done with this one?',
            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: Text(
          current.openCount > 0
              ? '${current.openCount} step${current.openCount == 1 ? '' : 's'} '
                  'still open. Marking it achieved keeps it in your history either way.'
              : 'It goes into your history as achieved, and you can set the next one.',
          style: const TextStyle(
              fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not yet', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Achieved',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _milestones.update(current.id, status: 'achieved');
    await _load();
  }

  // ─────────────────────────── build ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary))
                    : _error != null
                        ? _errorState()
                        : _milestone == null
                            ? _MilestoneSetup(
                                craft: profile?.profession,
                                onCreated: (m) => setState(() => _milestone = m),
                                onSetUpCraft: () async {
                                  final done = await CraftSetupSheet.show(context);
                                  if (done == true && mounted) setState(() {});
                                },
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                color: AppTheme.primary,
                                backgroundColor: AppTheme.bgCard,
                                child: _milestoneView(),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
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
                  Text('One milestone at a time',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          color: AppTheme.textMuted)),
                ],
              ),
            ),
            if (_milestone != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppTheme.textMuted, size: 20),
                color: AppTheme.bgCard,
                onSelected: (value) async {
                  if (value == 'finish') await _finish();
                  if (value == 'new') {
                    setState(() => _milestone = null);
                  }
                  if (value == 'delete') {
                    await _milestones.remove(_milestone!.id);
                    await _load();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'finish',
                      child: Text('Mark achieved',
                          style: TextStyle(
                              fontFamily: 'Outfit', color: AppTheme.textPrimary))),
                  PopupMenuItem(
                      value: 'new',
                      child: Text('Set a different milestone',
                          style: TextStyle(
                              fontFamily: 'Outfit', color: AppTheme.textPrimary))),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete this milestone',
                          style: TextStyle(
                              fontFamily: 'Outfit', color: Colors.redAccent))),
                ],
              ),
          ],
        ),
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load your milestone',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text(_error ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              SacredButton(label: 'Try again', onTap: _load),
            ],
          ),
        ),
      );

  Widget _milestoneView() {
    final m = _milestone!;
    final journal = context.watch<JournalProvider>();
    final accent = Professions.accentFor(m.craft);

    final workedDays = _workedDays(journal.entries);
    final workedToday = workedDays.contains(todayMarker());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _milestoneCard(m, accent),
        const SizedBox(height: 16),
        _analysis(m, accent, workedDays),
        const SizedBox(height: 18),
        _todaySwitch(accent, workedToday),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text('Your todos',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const Spacer(),
            Text('${m.doneCount}/${m.todos.length}',
                style: const TextStyle(
                    fontFamily: 'Outfit', fontSize: 12.5, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Yours to write and yours to delete. Tick one when it is actually done.',
          style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11.5,
              height: 1.5,
              color: AppTheme.textMuted),
        ),
        const SizedBox(height: 12),
        if (m.todos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'No steps yet. Write the first thing you would have to do — the '
              'smallest one that is still real.',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  height: 1.6,
                  color: AppTheme.textMuted),
            ),
          ),
        ...m.todos.map((todo) => _todoRow(todo, accent)),
        const SizedBox(height: 8),
        _addRow(),
      ],
    );
  }

  Widget _milestoneCard(Milestone m, Color accent) {
    final left = m.daysLeft;
    final overdue = left != null && left < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              const Text('MILESTONE',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted)),
              const Spacer(),
              if (left != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: overdue
                        ? AppTheme.danger.withValues(alpha: 0.22)
                        : Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    overdue
                        ? '${-left} day${left == -1 ? '' : 's'} over'
                        : left == 0
                            ? 'due today'
                            : '$left day${left == 1 ? '' : 's'} left',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: overdue ? Colors.redAccent : AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(m.title,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppTheme.textPrimary)),
          if (m.why.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(m.why,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: m.progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            m.todos.isEmpty
                ? 'Add the steps and this starts moving.'
                : '${(m.progress * 100).round()}% — ${m.doneCount} of ${m.todos.length} done',
            style: const TextStyle(
                fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  /// The honest part.
  ///
  /// Four numbers and one sentence. The sentence is the only opinion the screen
  /// offers, and it is allowed to be bad news: a milestone that will not be
  /// reached at the current pace should say so while there is still time to do
  /// something about it, not on the day it is missed.
  Widget _analysis(Milestone m, Color accent, Set<DateTime> workedDays) {
    final recent = workedDays
        .where((d) => todayMarker().difference(d).inDays < _windowDays)
        .length;
    final run = streakFromDates(workedDays);
    final left = m.daysLeft;

    // Days of work per week, from the fortnight. Two weeks is short enough to
    // reflect what is happening now and long enough not to swing on one day.
    final perWeek = recent / (_windowDays / 7);

    String verdict;
    Color verdictColor = AppTheme.textSecondary;

    if (m.todos.isEmpty) {
      verdict = 'Nothing to measure yet — write the steps below and this fills in.';
    } else if (m.openCount == 0) {
      verdict = 'Every step is done. Mark the milestone achieved from the menu.';
      verdictColor = AppTheme.success;
    } else if (recent == 0) {
      verdict =
          'No deep work recorded in the last fortnight. ${m.openCount} step${m.openCount == 1 ? '' : 's'} '
          'will not close themselves — pick the smallest one and do it today.';
      verdictColor = AppTheme.danger;
    } else if (left == null) {
      verdict =
          'You are working about ${perWeek.toStringAsFixed(1)} days a week. '
          'Set a target date from the menu if you want this to have an end.';
    } else {
      // Pace, in the only terms that matter: steps closed per day so far
      // against steps left over days left.
      final elapsed = DateTime.now().difference(m.createdAt).inDays + 1;
      final perDay = m.doneCount / elapsed;
      final needPerDay = left > 0 ? m.openCount / left : double.infinity;

      if (left < 0) {
        verdict =
            'The date has passed with ${m.openCount} step${m.openCount == 1 ? '' : 's'} open. '
            'Move the date rather than carrying the guilt — a target you have '
            'already missed stops being a target.';
        verdictColor = AppTheme.danger;
      } else if (perDay >= needPerDay && perDay > 0) {
        verdict =
            'On course. At the rate you have been closing steps, this lands '
            'before the date.';
        verdictColor = AppTheme.success;
      } else {
        final needPerWeek = (needPerDay * 7).ceil();
        verdict =
            'Behind. ${m.openCount} left in $left day${left == 1 ? '' : 's'} means about '
            '$needPerWeek a week, and you are closing fewer than that. Either '
            'the date moves or the list gets shorter.';
        verdictColor = AppTheme.accent;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How it is actually going',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('${(m.progress * 100).round()}%', 'done', accent),
              _stat('${m.openCount}', 'left', AppTheme.textPrimary),
              _stat('$recent', 'days worked', const Color(0xFF0EA5E9)),
              _stat('$run', run == 1 ? 'day run' : 'day run', AppTheme.accent),
            ],
          ),
          const SizedBox(height: 14),
          // The fortnight, as dots. Same shape as everywhere else in the app so
          // it reads without a legend.
          Row(
            children: List.generate(_windowDays, (i) {
              final day = todayMarker()
                  .subtract(Duration(days: _windowDays - 1 - i));
              final filled = workedDays.contains(day);
              return Container(
                width: 13,
                height: 13,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: filled ? accent : Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: day == todayMarker()
                      ? Border.all(color: AppTheme.textSecondary, width: 1.2)
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Text(verdict,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  height: 1.55,
                  color: verdictColor)),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Outfit', fontSize: 10.5, color: AppTheme.textMuted)),
          ],
        ),
      );

  /// Did you do the work today? One tap, and it is the same record the journal
  /// keeps — not a second, parallel idea of what counts.
  Widget _todaySwitch(Color accent, bool done) => InkWell(
        onTap: _busy.contains('_today') ? null : _markWorkedToday,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: done ? accent.withValues(alpha: 0.12) : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
                color: done ? accent.withValues(alpha: 0.45) : AppTheme.border),
          ),
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
                child: _busy.contains('_today')
                    ? const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : done
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  done
                      ? 'Deep work done today. That is the dot that fills in.'
                      : 'Did deep work today? Tap to record it.',
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _todoRow(MilestoneTodo todo, Color accent) {
    final working = _busy.contains(todo.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: todo.done ? accent.withValues(alpha: 0.08) : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
            color: todo.done ? accent.withValues(alpha: 0.35) : AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: working ? null : () => _toggleTodo(todo),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: todo.done ? accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: todo.done ? accent : AppTheme.textMuted,
                            width: 1.6),
                      ),
                      child: working
                          ? const Padding(
                              padding: EdgeInsets.all(3),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : todo.done
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : null,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        todo.label,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13.5,
                          height: 1.35,
                          color: todo.done
                              ? AppTheme.textMuted
                              : AppTheme.textPrimary,
                          decoration: todo.done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 17, color: AppTheme.textMuted),
            tooltip: 'Remove',
            onPressed: () => _removeTodo(todo),
          ),
        ],
      ),
    );
  }

  Widget _addRow() => Row(
        children: [
          Expanded(
            child: TextField(
              controller: _todoCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addTodo(),
              maxLength: 200,
              style: const TextStyle(
                  fontFamily: 'Outfit', fontSize: 13.5, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Add a step towards it',
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
            onPressed: _addTodo,
            style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ],
      );

  /// The days deep work actually happened, by local calendar day.
  ///
  /// Any craft tick counts, not only the one this screen writes: somebody who
  /// ticked "riyaaz" on the journal did the work, and having two definitions of
  /// a working day is how two screens end up disagreeing about the same week.
  Set<DateTime> _workedDays(List<JournalEntry> entries) => entries
      .where((e) => e.didCraft)
      .map((e) => dayMarker(e.createdAt))
      .toSet();
}

/// Choosing the milestone. The first screen anybody sees here.
///
/// Seeded from their craft, because "next milestone" is an intimidating blank
/// for most people and a recognisable one when it is phrased in their own work.
/// Every suggestion is editable — they fill the box rather than being chosen.
class _MilestoneSetup extends StatefulWidget {
  final String? craft;
  final void Function(Milestone) onCreated;
  final VoidCallback onSetUpCraft;

  const _MilestoneSetup({
    required this.craft,
    required this.onCreated,
    required this.onSetUpCraft,
  });

  @override
  State<_MilestoneSetup> createState() => _MilestoneSetupState();
}

class _MilestoneSetupState extends State<_MilestoneSetup> {
  final _service = MilestoneService();
  final _titleCtrl = TextEditingController();
  final _whyCtrl = TextEditingController();
  DateTime? _target;
  bool _saving = false;

  /// A handful of milestones per craft, in the shape people actually say them.
  static const _suggestions = <String, List<String>>{
    'student': [
      'Finish the syllabus for one subject',
      'Score above 80 in the next test',
      'Clear the backlog of unwatched lectures',
    ],
    'engineer': [
      'Ship the side project people can use',
      'Switch jobs — offer in hand',
      'Finish the system design course',
    ],
    'singer': ['Record one song end to end', 'Perform in front of people'],
    'writer': ['Finish the first draft', 'Publish four pieces'],
    'artist': ['Complete a series of ten', 'Hold a small show'],
    'athlete': ['Run the distance without stopping', 'Hit the lift target'],
    'entrepreneur': ['Get the first ten paying users', 'Launch the thing'],
    'teacher': ['Build the course and teach it once'],
  };

  List<String> get _ideas =>
      _suggestions[widget.craft ?? ''] ??
      const [
        'Finish the thing I keep restarting',
        'Learn it well enough to use it',
        'Build the habit for sixty days',
      ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _whyCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final milestone = await _service.create(
        title: title,
        why: _whyCtrl.text.trim(),
        craft: widget.craft ?? '',
        targetDate: _target,
      );
      widget.onCreated(milestone);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save that: $e',
              style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final craft = Professions.byId(widget.craft);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        const Text('🎯', style: TextStyle(fontSize: 30)),
        const SizedBox(height: 10),
        const Text(
          'What are you trying to finish?',
          style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'One milestone, not a list. Something you could hold up and say — '
          'that is done. The steps come after.',
          style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              height: 1.6,
              color: AppTheme.textMuted),
        ),
        const SizedBox(height: 20),

        // The craft, when they have named one — the suggestions are only
        // recognisable because they are in the language of the work.
        if (widget.craft == null || widget.craft!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: widget.onSetUpCraft,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border:
                      Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tell the app what you are getting good at first — the '
                        'suggestions and the wording follow from it.',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            height: 1.5,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 18, color: AppTheme.primary),
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('${craft.emoji}  ${craft.label}',
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _ideas
              .map((idea) => GestureDetector(
                    onTap: () => setState(() => _titleCtrl.text = idea),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(idea,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),

        _field(_titleCtrl, 'The milestone', 'Ship the side project', 200),
        const SizedBox(height: 12),
        _field(_whyCtrl, 'Why it matters (optional)',
            'So I can apply with something real', 1000, lines: 2),
        const SizedBox(height: 14),

        // A date is optional, and the copy says so. Inventing a deadline for
        // somebody is how an app starts lying about urgency.
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _target ?? now.add(const Duration(days: 30)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 365 * 3)),
            );
            if (picked != null) setState(() => _target = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_outlined,
                    size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _target == null
                        ? 'By when? (optional)'
                        : 'By ${_target!.day}/${_target!.month}/${_target!.year}',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: _target == null
                            ? AppTheme.textMuted
                            : AppTheme.textPrimary),
                  ),
                ),
                if (_target != null)
                  GestureDetector(
                    onTap: () => setState(() => _target = null),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppTheme.textMuted),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SacredButton(
          label: _saving ? 'Saving…' : 'Set this milestone',
          icon: Icons.arrow_forward_rounded,
          onTap: _create,
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, int max,
          {int lines = 1}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: lines,
            maxLength: max,
            style: const TextStyle(
                fontFamily: 'Outfit', fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              hintStyle: const TextStyle(
                  fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.bgCard,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
        ],
      );
}
