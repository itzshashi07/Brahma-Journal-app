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

/// Deep work: the milestones being worked on, and whether they are on course.
///
/// ─────────────────────────────────────────────────────────────────────────
/// The order is the feature
///
/// **Milestones first.** Everything else this app measures is a habit — did you
/// sit, did you write, did you practise. Habits answer "did you turn up", which
/// the journal and the streak already answer well, and cannot answer "is the
/// thing getting finished". For somebody working towards a job switch, an album
/// or an exam that is the only question that matters.
///
/// **As many as they actually have.** This screen ran one milestone at a time
/// for about a day, on the reasoning that three current goals is a backlog. That
/// is a fine opinion about focus and a wrong one about lives: somebody studying
/// for an exam is also training for a race and also shipping a side project.
/// They all live here, each with its own steps and its own verdict.
///
/// **And each belongs to a craft, chosen per milestone.** The stamp used to be
/// `profile.profession` — the single craft named at setup — so an engineer who
/// also sings had every milestone filed under engineering and was offered
/// system design courses while trying to record a song. The chooser is on the
/// setup screen with the profile's craft preselected, and the list groups by it
/// once there is more than one in play: two tracks read as two tracks, rather
/// than as one list somebody is permanently behind on.
///
/// **Then the member's own todos**, per milestone. Add, tick, delete, and
/// nothing else — no priorities, no sub-tasks, no dependencies. Anything more is
/// a second job.
///
/// **Then the analysis, and it is allowed to be bad news.** Percent done, steps
/// left, days of real deep work in the last fortnight, the current run, and one
/// sentence of verdict. An app that only ever says "great job" is one nobody
/// believes the third time.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Where the numbers come from
///
/// The milestones and their todos are their own record
/// (`/api/practice/milestones`). The *days worked* are the journal's, read from
/// `craftDone` by local calendar day, so this screen and the consistency chart
/// cannot disagree about what a day of deep work was. Achievements are counted
/// by the server, month by month, and shown here and on the analytics screen —
/// see `MilestoneService.achievements`.
class DeepWorkScreen extends StatefulWidget {
  const DeepWorkScreen({super.key});

  @override
  State<DeepWorkScreen> createState() => _DeepWorkScreenState();
}

class _DeepWorkScreenState extends State<DeepWorkScreen> {
  final _service = MilestoneService();

  List<Milestone> _milestones = const [];
  AchievementHistory _achievements = const AchievementHistory(total: 0, months: []);
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?.uid;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Issued together: the achievements count does not depend on the list,
      // and the entries back the "days worked" half of every verdict.
      final results = await Future.wait([
        _service.all(),
        _service.achievements(),
        if (uid != null) context.read<JournalProvider>().loadEntries(uid),
      ]);

      if (!mounted) return;
      setState(() {
        _milestones = results[0] as List<Milestone>;
        _achievements = results[1] as AchievementHistory;
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

  List<Milestone> get _active =>
      _milestones.where((m) => m.isActive).toList();

  Future<void> _openDetail(Milestone milestone) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MilestoneDetail(milestone: milestone),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _newMilestone() async {
    final craft = context.read<AuthProvider>().profile?.profession;

    final created = await Navigator.of(context).push<Milestone>(
      MaterialPageRoute(
        builder: (_) => _MilestoneSetupScreen(
          craft: craft,
          onSetUpCraft: () => CraftSetupSheet.show(context),
        ),
      ),
    );

    if (created != null && mounted) {
      await _load();
      if (mounted) await _openDetail(created);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppTheme.primary,
                            backgroundColor: AppTheme.bgCard,
                            child: _list(),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _loading || _active.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _newMilestone,
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New milestone',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
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
                  Text('What you are building',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          color: AppTheme.textMuted)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.insights_rounded,
                  color: AppTheme.textMuted, size: 20),
              tooltip: 'Your patterns',
              onPressed: () => context.push('/analytics'),
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
              const Text('Could not load your milestones',
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

  Widget _list() {
    final active = _active;
    final journal = context.watch<JournalProvider>();
    final workedDays = journal.entries
        .where((e) => e.didCraft)
        .map((e) => dayMarker(e.createdAt))
        .toSet();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: [
        if (_achievements.total > 0) _achievementStrip(),
        if (_achievements.total > 0) const SizedBox(height: 18),

        if (active.isEmpty)
          _emptyState()
        else ...[
          Row(
            children: [
              const Text('In progress',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              Text('${active.length}',
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          ..._byCraft(active, workedDays),
        ],
      ],
    );
  }

  /// The active milestones, under a heading per craft.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// Why the grouping only appears when there is something to group
  ///
  /// Somebody running two milestones for one craft is looking at a list, and a
  /// heading above a list of two that all belong to the same thing is furniture.
  /// Somebody running an engineering milestone and a singing one is looking at
  /// two different lives, and reading them as one undifferentiated list is how
  /// "I am behind on everything" happens — the mixed list hides that each track
  /// is fine on its own terms.
  ///
  /// So: one craft, no headings. More than one, a heading each, ordered by how
  /// many are running so the busiest track is at the top.
  List<Widget> _byCraft(List<Milestone> active, Set<DateTime> workedDays) {
    final groups = <String, List<Milestone>>{};
    for (final m in active) {
      groups.putIfAbsent(m.craft, () => []).add(m);
    }

    if (groups.length < 2) {
      return active.map((m) => _milestoneTile(m, workedDays)).toList();
    }

    final keys = groups.keys.toList()
      ..sort((a, b) {
        final byCount = groups[b]!.length.compareTo(groups[a]!.length);
        if (byCount != 0) return byCount;
        return Professions.byId(a).label.compareTo(Professions.byId(b).label);
      });

    return [
      for (final key in keys) ...[
        _craftHeading(key, groups[key]!.length),
        ...groups[key]!.map((m) => _milestoneTile(m, workedDays)),
        const SizedBox(height: 6),
      ],
    ];
  }

  Widget _craftHeading(String craft, int count) {
    final profession = Professions.byId(craft);
    final accent = Professions.accentFor(craft);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: [
          Text(profession.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 7),
          Text(profession.label,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: accent)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: accent.withValues(alpha: 0.22),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  /// Achievements, month by month, right where the work is.
  ///
  /// The full history lives on the analytics screen; this is the last three
  /// months, because the question this screen answers is "am I finishing
  /// things lately" rather than "what did I do in March".
  Widget _achievementStrip() {
    final months = _achievements.months.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 7),
              Text(
                '${_achievements.total} achieved',
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/analytics'),
                child: const Text('All of it →',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.5,
                        color: AppTheme.primaryLight)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...months.map((month) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 108,
                      child: Text(month.label,
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              fontWeight: month.isThisMonth
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: month.isThisMonth
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary)),
                    ),
                    // A bar rather than only a number: three months of counts
                    // side by side is a shape, and a shape is read faster than
                    // three integers.
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (month.count /
                                  (_achievements.busiest?.count ?? 1))
                              .clamp(0.08, 1),
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          valueColor:
                              const AlwaysStoppedAnimation(AppTheme.success),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${month.count}',
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Column(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 14),
            const Text(
              'Nothing in progress',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'A milestone is something you could hold up and say — that is '
              'done. Set as many as you are actually working on; each one keeps '
              'its own steps and its own honest verdict.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  height: 1.6,
                  color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            SacredButton(
              label: 'Set your first milestone',
              icon: Icons.arrow_forward_rounded,
              onTap: _newMilestone,
            ),
          ],
        ),
      );

  /// One milestone, as a row on the list.
  ///
  /// Enough to decide whether to open it: how far along, how long is left, and
  /// whether any work has gone in this week. Everything else is inside.
  Widget _milestoneTile(Milestone m, Set<DateTime> workedDays) {
    final accent = Professions.accentFor(m.craft);
    final left = m.daysLeft;
    final overdue = left != null && left < 0;
    final thisWeek = workedDays
        .where((d) => todayMarker().difference(d).inDays < 7)
        .length;

    return GestureDetector(
      onTap: () => _openDetail(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(m.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: AppTheme.textPrimary)),
                ),
                const SizedBox(width: 10),
                if (left != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: overdue
                          ? AppTheme.danger.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      overdue
                          ? '${-left}d over'
                          : left == 0
                              ? 'today'
                              : '${left}d left',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color:
                              overdue ? Colors.redAccent : AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: m.progress,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  m.todos.isEmpty
                      ? 'No steps yet'
                      : '${m.doneCount} of ${m.todos.length} done',
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11.5,
                      color: AppTheme.textSecondary),
                ),
                const Spacer(),
                Text(
                  thisWeek == 0
                      ? 'nothing this week'
                      : '$thisWeek day${thisWeek == 1 ? '' : 's'} this week',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11.5,
                      color: thisWeek == 0 ? AppTheme.accent : AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One milestone, opened: the analysis, today's tick, and the todos.
class _MilestoneDetail extends StatefulWidget {
  final Milestone milestone;

  const _MilestoneDetail({required this.milestone});

  @override
  State<_MilestoneDetail> createState() => _MilestoneDetailState();
}

class _MilestoneDetailState extends State<_MilestoneDetail> {
  final _milestones = MilestoneService();
  final _todoCtrl = TextEditingController();

  late Milestone? _milestone = widget.milestone;

  /// Ids being written right now, so a second tap is ignored rather than racing
  /// the first.
  final Set<String> _busy = {};

  static const _windowDays = 14;

  @override
  void dispose() {
    _todoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?.uid;
    try {
      final all = await _milestones.all();
      if (uid != null && mounted) {
        await context.read<JournalProvider>().loadEntries(uid);
      }
      if (!mounted) return;
      final match = all.where((m) => m.id == widget.milestone.id);
      setState(() => _milestone = match.isEmpty ? _milestone : match.first);
    } catch (_) {
      // The screen already has a milestone to render; a failed refresh is not
      // worth replacing it with an error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _detailHeader(),
              Expanded(
                child: _milestone == null
                    ? const SizedBox.shrink()
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

  Widget _detailHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: AppTheme.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const Expanded(
              child: Text('Milestone',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppTheme.textMuted, size: 20),
              color: AppTheme.bgCard,
              onSelected: (value) async {
                if (value == 'finish') await _finish();
                if (value == 'drop') {
                  await _milestones.update(_milestone!.id, status: 'dropped');
                  if (mounted) Navigator.of(context).pop();
                }
                if (value == 'delete') {
                  await _milestones.remove(_milestone!.id);
                  if (mounted) Navigator.of(context).pop();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'finish',
                    child: Text('Mark achieved',
                        style: TextStyle(
                            fontFamily: 'Outfit', color: AppTheme.textPrimary))),
                PopupMenuItem(
                    value: 'drop',
                    child: Text('Drop it',
                        style: TextStyle(
                            fontFamily: 'Outfit', color: AppTheme.textPrimary))),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(
                            fontFamily: 'Outfit', color: Colors.redAccent))),
              ],
            ),
          ],
        ),
      );

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

    // Back to the list, which reloads on return — an achieved milestone is not
    // in progress any more, and leaving its detail on screen invites somebody
    // to keep ticking steps on something they have just finished.
    if (mounted) Navigator.of(context).pop();
  }

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


/// Setting a milestone.
///
/// Seeded from their craft, because "next milestone" is an intimidating blank
/// for most people and a recognisable one when it is phrased in their own work.
/// Every suggestion is editable — they fill the box rather than being chosen.
///
/// A pushed screen rather than an empty state, because there can be several
/// milestones now: this is reached from the "+" as often as from having none.
/// It pops with the milestone it created.
class _MilestoneSetupScreen extends StatefulWidget {
  final String? craft;
  final VoidCallback onSetUpCraft;

  const _MilestoneSetupScreen({
    required this.craft,
    required this.onSetUpCraft,
  });

  @override
  State<_MilestoneSetupScreen> createState() => _MilestoneSetupScreenState();
}

class _MilestoneSetupScreenState extends State<_MilestoneSetupScreen> {
  final _service = MilestoneService();
  final _titleCtrl = TextEditingController();
  final _whyCtrl = TextEditingController();
  DateTime? _target;
  bool _saving = false;

  /// Which part of this person's life this milestone belongs to.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// Why it is chosen here and not read from the profile
  ///
  /// It used to be `profile.profession`, full stop — so every milestone anybody
  /// set was stamped with the one craft they had named at setup. An engineer
  /// who also sings had to pick which half of themselves the app was allowed to
  /// know about, and then watched it suggest system design courses when they
  /// were trying to record a song. People are not one thing, and a screen about
  /// what somebody is building has no business insisting otherwise.
  ///
  /// The profile's craft is still the default, because for most people most of
  /// the time it is right and a chooser that has to be answered every time is a
  /// tax on the common case. Changing it here changes this milestone only: the
  /// daily habit card in the journal still follows the profile.
  late String _craft = widget.craft ?? '';

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
      _suggestions[_craft] ??
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
        craft: _craft,
        targetDate: _target,
      );
      if (mounted) Navigator.of(context).pop(milestone);
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
    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: AppTheme.textPrimary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text('New milestone',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(child: _form()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
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
        const Text(
          'Something you could hold up and say — that is done. The steps come '
          'after.',
          style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              height: 1.6,
              color: AppTheme.textMuted),
        ),
        const SizedBox(height: 20),

        _craftChooser(),
        const SizedBox(height: 18),

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

  /// Which part of their life this one belongs to.
  ///
  /// Every craft in the catalogue, not only the one on the profile, because the
  /// whole point is that somebody has more than one. The profile's is first and
  /// preselected — the common case stays one glance and no taps — and the rest
  /// scroll horizontally rather than opening a picker, so choosing "singer"
  /// when the profile says "engineer" costs a single tap.
  Widget _craftChooser() {
    final ordered = [
      ...Professions.all.where((p) => p.id == widget.craft),
      ...Professions.all.where((p) => p.id != widget.craft),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Which part of your life?',
            style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        const Text(
          'Milestones are grouped by this, and the suggestions follow it. You '
          'can run one for each.',
          style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11.5,
              height: 1.45,
              color: AppTheme.textMuted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ordered.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = ordered[i];
              final on = p.id == _craft;
              final accent = Professions.accentFor(p.id);

              return GestureDetector(
                onTap: () => setState(() => _craft = p.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: on
                        ? accent.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: on ? accent : AppTheme.border,
                      width: on ? 1.4 : 1,
                    ),
                  ),
                  child: Text('${p.emoji}  ${p.label}',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                          color: on
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary)),
                ),
              );
            },
          ),
        ),

        // The daily habit card in the journal is still driven by the profile's
        // craft, so somebody who has never set one is offered that here — the
        // milestone itself does not need it.
        if (widget.craft == null || widget.craft!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: widget.onSetUpCraft,
              child: const Text(
                'Set your daily practice too →',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryLight),
              ),
            ),
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
