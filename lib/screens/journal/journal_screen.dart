import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/journal_entry.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/constants/professions.dart';
import '../../widgets/craft_setup_sheet.dart';
import '../../widgets/sacred.dart';
import '../../widgets/voice_input_button.dart';
import '../../widgets/journal_chips.dart';
import '../../core/constants/journal_options.dart';

/// The daily journal.
///
/// The old layout was a single scroll of sixteen identically-weighted fields
/// with no hierarchy: mood, then a wall of chips, then eleven text boxes that
/// all looked equally mandatory. Opened at 11pm it read as homework, and the
/// honest outcome was an empty day.
///
/// This version is built around what people actually do:
///   • one mood tap,
///   • one line about the day (spoken or typed),
///   • a handful of chips,
/// which is a complete, honest entry and takes under a minute. Everything
/// longer lives inside collapsed sections that announce themselves as optional,
/// so the page is short until somebody chooses to make it long.
///
/// The save bar is pinned rather than parked at the bottom of the scroll: the
/// most common failure of the old screen was writing something and never
/// reaching the button.
class JournalScreen extends StatefulWidget {
  final JournalEntry? entry;
  const JournalScreen({super.key, this.entry});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  int _selectedMood = 3;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _dirty = false;
  String? _existingEntryId;

  final _newHabitCtrl = TextEditingController();
  final _tinyStepCtrl = TextEditingController();
  final _badHabitCtrl = TextEditingController();
  final _affirmationsCtrl = TextEditingController();
  final _visualizationCtrl = TextEditingController();
  final _nightRoutineCtrl = TextEditingController();
  final _triggerThoughtCtrl = TextEditingController();
  final _triggerResponseCtrl = TextEditingController();
  final _bestMomentCtrl = TextEditingController();
  final _shivBabaLineCtrl = TextEditingController();
  final _sleepReflectionCtrl = TextEditingController();

  // Tap-to-select state.
  Set<String> _energy = {};
  Set<String> _practices = {};
  Set<String> _influences = {};
  Set<String> _habits = {};
  Set<String> _challenges = {};

  /// What they did today towards their own craft, plus optional minutes.
  Set<String> _craft = {};
  final _craftMinutesCtrl = TextEditingController();

  /// Which optional writing sections are open. All closed on arrival — the
  /// page has to look finishable before anyone will start it.
  final _open = <String, bool>{
    'growth': false,
    'mind': false,
    'night': false,
  };

  List<TextEditingController> get _allControllers => [
        _newHabitCtrl, _tinyStepCtrl, _badHabitCtrl, _affirmationsCtrl,
        _visualizationCtrl, _nightRoutineCtrl, _triggerThoughtCtrl,
        _triggerResponseCtrl, _bestMomentCtrl, _shivBabaLineCtrl,
        _sleepReflectionCtrl,
      ];

  /// How much of the journal is filled. Shown as a gentle number, never as a
  /// bar that shames you for stopping at 40%.
  int get _filledCount {
    var n = 0;
    for (final c in _allControllers) {
      if (c.text.trim().isNotEmpty) n++;
    }
    for (final set in [_energy, _practices, _influences, _habits, _challenges]) {
      if (set.isNotEmpty) n++;
    }
    return n;
  }

  static const int _totalCount = 16;

  /// The three things that make an entry feel done. Everything else is extra,
  /// and the UI should say so.
  bool get _essentialsDone =>
      _bestMomentCtrl.text.trim().isNotEmpty || _energy.isNotEmpty;

  bool get _isReadOnly {
    if (widget.entry == null) return false;
    final today = DateTime.now();
    final entryDate = widget.entry!.createdAt;
    return !(entryDate.year == today.year &&
        entryDate.month == today.month &&
        entryDate.day == today.day);
  }

  @override
  void initState() {
    super.initState();
    for (final c in _allControllers) {
      // Dictation writes straight into the controller, so onChanged on the
      // field would miss every spoken word — the counter and the save bar's
      // enabled state both depend on noticing that.
      c.addListener(_onEdited);
    }
    _loadToday();
  }

  void _onEdited() {
    if (!mounted) return;
    setState(() => _dirty = true);
  }

  Future<void> _loadToday() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final journal = context.read<JournalProvider>();
    if (auth.user != null && journal.entries.isEmpty) {
      await journal.loadEntries(auth.user!.uid);
    }
    if (!mounted) return;
    final target = widget.entry ?? context.read<JournalProvider>().todaysEntry;
    if (target != null) {
      _existingEntryId = target.id;
      _selectedMood = target.mood;
      _newHabitCtrl.text = target.newHabit;
      _tinyStepCtrl.text = target.tinyStep;
      _badHabitCtrl.text = target.badHabit;
      _affirmationsCtrl.text = target.affirmations;
      _visualizationCtrl.text = target.visualization;
      _nightRoutineCtrl.text = target.nightRoutine;
      _triggerThoughtCtrl.text = target.triggerThought;
      _triggerResponseCtrl.text = target.triggerResponse;
      _bestMomentCtrl.text = target.bestMoment;
      _shivBabaLineCtrl.text = target.shivBabaLine;
      _energy = target.energyLevel.isEmpty ? {} : {target.energyLevel};
      _practices = target.practices.toSet();
      _influences = target.influences.toSet();
      _habits = target.habitsDone.toSet();
      _challenges = target.challenges.toSet();
      _craft = target.craftDone.toSet();
      if (target.craftMinutes > 0) {
        _craftMinutesCtrl.text = '${target.craftMinutes}';
      }
      _sleepReflectionCtrl.text = target.sleepReflection;
    }
    setState(() {
      _isLoading = false;
      // Prefilling the controllers fired every listener; none of it is a user
      // edit, so the save bar should not light up as though it were.
      _dirty = false;
    });
  }

  Future<void> _saveEntry() async {
    if (_isReadOnly) return;
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      // Anything the check-in already recorded today is carried through, so
      // saving from this screen never quietly erases it.
      final existing = context.read<JournalProvider>().todaysEntry;
      final entry = JournalEntry(
        uid: auth.user!.uid,
        mood: _selectedMood,
        newHabit: _newHabitCtrl.text,
        tinyStep: _tinyStepCtrl.text,
        badHabit: _badHabitCtrl.text,
        affirmations: _affirmationsCtrl.text,
        visualization: _visualizationCtrl.text,
        nightRoutine: _nightRoutineCtrl.text,
        triggerThought: _triggerThoughtCtrl.text,
        triggerResponse: _triggerResponseCtrl.text,
        bestMoment: _bestMomentCtrl.text,
        shivBabaLine: _shivBabaLineCtrl.text,
        energyLevel: _energy.isEmpty ? '' : _energy.first,
        practices: _practices.toList(),
        influences: _influences.toList(),
        habitsDone: _habits.toList(),
        challenges: _challenges.toList(),
        sleepReflection: _sleepReflectionCtrl.text,
        checkIn: widget.entry?.checkIn ?? existing?.checkIn ?? const {},
        craftDone: _craft.toList(),
        craftMinutes: int.tryParse(_craftMinutesCtrl.text.trim()) ?? 0,
        createdAt: widget.entry?.createdAt ?? DateTime.now(),
      );
      final id = await context
          .read<JournalProvider>()
          .saveEntry(entry, existingId: _existingEntryId);
      if (!mounted) return;
      setState(() {
        _existingEntryId = id;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved. See you tomorrow.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _allControllers) {
      c.removeListener(_onEdited);
      c.dispose();
    }
    _craftMinutesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalProvider>();
    final entryDate = widget.entry?.createdAt ?? DateTime.now();

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _header(journal.streak, entryDate),
              if (_isLoading)
                const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(color: AppTheme.primary)),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.space4, 0, AppTheme.space4, AppTheme.space6),
                    children:
                        _isReadOnly ? _readingView() : _writingView(),
                  ),
                ),
              if (!_isReadOnly && !_isLoading) _saveBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── header ───────────────────────────

  Widget _header(int streak, DateTime entryDate) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.space2, AppTheme.space3, AppTheme.space4, AppTheme.space3),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimary, size: 22),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isReadOnly ? 'Past reflection' : 'Today',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  AppDateUtils.formatDate(entryDate),
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (!_isReadOnly && streak > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border:
                    Border.all(color: AppTheme.accent.withValues(alpha: 0.32)),
              ),
              child: Text(
                '🔥 $streak',
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AppTheme.accentLight,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────── writing ───────────────────────────

  List<Widget> _writingView() {
    return [
      // The line for the day. Short, quotable, and the same all day so it
      // reads as something said to you rather than as decoration.
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.space4),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.format_quote_rounded,
                size: 17, color: AppTheme.accentLight),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Text(
                JournalPrompts.forToday(),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppTheme.space5),

      // 1 — mood
      _Card(
        step: '1',
        title: 'How are you today?',
        subtitle: 'One tap. This is the part that matters most.',
        child: _moodRow(),
      ),
      const SizedBox(height: AppTheme.space4),

      // 2 — the one line
      _Card(
        step: '2',
        title: 'Say something about today',
        subtitle: 'Type it, or tap the mic and just speak.',
        child: _WriteField(
          controller: _bestMomentCtrl,
          hint: 'Anything at all. One sentence is a complete entry.',
          lines: 4,
          emphasised: true,
        ),
      ),
      const SizedBox(height: AppTheme.space4),

      // 3 — the chips
      _Card(
        step: '3',
        title: 'Tap what fits',
        subtitle: 'Twenty seconds. Nothing here is required.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChipGroupField(
              label: 'Energy today',
              hint: 'pick one',
              singleChoice: true,
              options: JournalOptions.energyLevels,
              selected: _energy,
              onChanged: (v) => setState(() {
                _energy = v;
                _dirty = true;
              }),
            ),
            const SizedBox(height: AppTheme.space5),
            ChipGroupField(
              label: 'Practices',
              hint: 'tap any',
              options: JournalOptions.practices,
              selected: _practices,
              onChanged: (v) => setState(() {
                _practices = v;
                _dirty = true;
              }),
            ),
            const SizedBox(height: AppTheme.space5),
            ChipGroupField(
              label: 'What shaped today',
              hint: 'tap any',
              options: JournalOptions.influences,
              selected: _influences,
              onChanged: (v) => setState(() {
                _influences = v;
                _dirty = true;
              }),
            ),
            const SizedBox(height: AppTheme.space5),
            ChipGroupField(
              label: 'Things that went right',
              hint: 'tap any',
              options: JournalOptions.habits,
              selected: _habits,
              onChanged: (v) => setState(() {
                _habits = v;
                _dirty = true;
              }),
            ),
            const SizedBox(height: AppTheme.space5),
            ChipGroupField(
              label: 'What pulled at you',
              hint: 'tap any',
              options: JournalOptions.challenges,
              selected: _challenges,
              onChanged: (v) => setState(() {
                _challenges = v;
                _dirty = true;
              }),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppTheme.space4),

      // 4 — the craft. The one section that answers "am I actually doing the
      // thing I said I cared about", which mood and meditation minutes cannot.
      _craftCard(),
      const SizedBox(height: AppTheme.space6),

      // Everything below is explicitly extra.
      Row(
        children: [
          const Expanded(child: Divider(color: AppTheme.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
            child: Text(
              'That is already a full entry',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                color: AppTheme.textMuted.withValues(alpha: 0.9),
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppTheme.border)),
        ],
      ),
      const SizedBox(height: AppTheme.space4),
      const Text(
        'Want to go deeper?',
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      const SizedBox(height: 2),
      const Text(
        'Open any of these on the evenings you have more to say.',
        style: TextStyle(
            fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted),
      ),
      const SizedBox(height: AppTheme.space4),

      _Section(
        icon: Icons.trending_up_rounded,
        title: 'Habits & direction',
        summary: 'What you are building, and what you are putting down',
        open: _open['growth']!,
        filled: _countFilled(
            [_newHabitCtrl, _tinyStepCtrl, _badHabitCtrl, _visualizationCtrl]),
        total: 4,
        onToggle: () => setState(() => _open['growth'] = !_open['growth']!),
        children: [
          _WriteField(
              controller: _newHabitCtrl,
              label: 'A habit you are building',
              hint: 'What are you trying to make normal?'),
          _WriteField(
              controller: _tinyStepCtrl,
              label: 'The smallest step you took',
              hint: 'Tiny counts. Tiny is the whole method.'),
          _WriteField(
              controller: _badHabitCtrl,
              label: 'A habit you are letting go of',
              hint: 'Name it without beating yourself up about it.'),
          _WriteField(
              controller: _visualizationCtrl,
              label: 'Where this is going',
              hint: 'Describe the day you are working towards…',
              lines: 3),
        ],
      ),
      const SizedBox(height: AppTheme.space3),

      _Section(
        icon: Icons.psychology_outlined,
        title: 'Mind & inner work',
        summary: 'The thought that caught you, and what you told yourself',
        open: _open['mind']!,
        filled: _countFilled([
          _triggerThoughtCtrl,
          _triggerResponseCtrl,
          _affirmationsCtrl,
          _shivBabaLineCtrl
        ]),
        total: 4,
        onToggle: () => setState(() => _open['mind'] = !_open['mind']!),
        children: [
          _WriteField(
              controller: _triggerThoughtCtrl,
              label: 'A thought that pulled you down',
              hint: 'What went through your head?'),
          _WriteField(
              controller: _triggerResponseCtrl,
              label: 'A kinder way to answer it',
              hint: 'What would you say to a friend who thought this?',
              lines: 2),
          _WriteField(
              controller: _affirmationsCtrl,
              label: 'What you want to keep telling yourself',
              hint: 'In your own words, not borrowed ones…',
              lines: 3),
          _WriteField(
              // Was "Shiv Baba's Line", which only makes sense inside one
              // tradition. Reworded so a member of any faith — or none — can
              // answer it honestly.
              controller: _shivBabaLineCtrl,
              label: 'A line that stayed with you',
              hint: 'From scripture, a book, a talk, a song — anything.',
              lines: 2),
        ],
      ),
      const SizedBox(height: AppTheme.space3),

      _Section(
        icon: Icons.bedtime_outlined,
        title: 'Night & rest',
        summary: 'How the day is ending, and how last night went',
        open: _open['night']!,
        filled: _countFilled([_nightRoutineCtrl, _sleepReflectionCtrl]),
        total: 2,
        onToggle: () => setState(() => _open['night'] = !_open['night']!),
        children: [
          _WriteField(
              controller: _nightRoutineCtrl,
              label: 'Tonight\'s plan',
              hint: 'How do you want the last hour of today to go?',
              lines: 2),
          _WriteField(
              controller: _sleepReflectionCtrl,
              label: 'Last night\'s sleep',
              hint: 'How did you sleep? Any dreams worth keeping?',
              lines: 2),
        ],
      ),
      const SizedBox(height: AppTheme.space6),
    ];
  }

  int _countFilled(List<TextEditingController> cs) =>
      cs.where((c) => c.text.trim().isNotEmpty).length;

  /// Today's work towards whatever this member is trying to get good at.
  ///
  /// Before they have named a craft this is an invitation rather than an empty
  /// grid — a card of chips for a profession nobody chose would be noise.
  Widget _craftCard() {
    final profile = context.watch<AuthProvider>().profile;

    if (profile == null || !profile.hasCraft) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.space4),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 17)),
                const SizedBox(width: AppTheme.space2),
                const Expanded(
                  child: Text(
                    'What are you trying to get good at?',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Singing, writing, studying, building something. Name it once and '
              'this journal starts showing whether you are actually doing it.',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  height: 1.5,
                  color: AppTheme.textMuted),
            ),
            const SizedBox(height: AppTheme.space3),
            SacredButton(
              label: 'Set it up — takes 20 seconds',
              icon: Icons.arrow_forward_rounded,
              secondary: true,
              onTap: () async {
                final done = await CraftSetupSheet.show(context);
                if (done == true && mounted) setState(() {});
              },
            ),
          ],
        ),
      );
    }

    final craft = Professions.byId(profile.profession);
    final accent = Professions.accentFor(craft.id);

    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Text('4',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${craft.emoji}  Your ${craft.workWord} today',
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    Text(
                      (profile.aim ?? '').isEmpty
                          ? 'Tap anything you did. Nothing is also an answer.'
                          : profile.aim!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final done = await CraftSetupSheet.show(context);
                  if (done == true && mounted) {
                    // A changed profession means the old preset ids no longer
                    // belong to any chip on this card; keeping them would save
                    // ids the analytics screen cannot label.
                    //
                    // Custom items survive, because they are not tied to the
                    // craft that was chosen — someone switching from Student to
                    // Engineer is still going to the gym, and silently
                    // unticking it would be the app deciding they did not.
                    setState(() => _craft = _craft
                        .where((id) => id.startsWith(CraftHabit.customPrefix))
                        .toSet());
                  }
                },
                child: const Icon(Icons.tune_rounded,
                    size: 17, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          // Presets first, then whatever this member added for themselves. Both
          // tick identically and both land in `craftDone`, so nothing further
          // down has to care which is which.
          Wrap(
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space2,
            children: profile.checklist.map((h) {
              final on = _craft.contains(h.id);
              return GestureDetector(
                onTap: () => setState(() {
                  on ? _craft.remove(h.id) : _craft.add(h.id);
                  _dirty = true;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: on
                        ? accent.withValues(alpha: 0.24)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                      color: on ? accent : AppTheme.border,
                      width: on ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(h.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        h.label,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12.5,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                          color:
                              on ? AppTheme.textPrimary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_craft.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space4),
            Row(
              children: [
                const Text(
                  'How long?',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      color: AppTheme.textSecondary),
                ),
                const SizedBox(width: AppTheme.space3),
                SizedBox(
                  width: 78,
                  child: TextField(
                    controller: _craftMinutesCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: '—',
                      hintStyle: const TextStyle(
                          fontFamily: 'Outfit', color: AppTheme.textMuted),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space2),
                const Text(
                  'minutes · optional',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11.5,
                      color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _moodRow() {
    const labels = {
      1: ('Restless', Color(0xFFEF4444), '😣'),
      2: ('Heavy', Color(0xFFF59E0B), '😔'),
      3: ('Neutral', Color(0xFF6B7280), '😐'),
      4: ('Calm', Color(0xFF3B82F6), '🙂'),
      5: ('Joyful', Color(0xFF10B981), '😊'),
    };

    return Row(
      children: [1, 2, 3, 4, 5].map((val) {
        final (label, color, emoji) = labels[val]!;
        final isSelected = _selectedMood == val;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedMood = val;
              _dirty = true;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space3),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: isSelected ? color : AppTheme.border,
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? color : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────── save bar ───────────────────────────

  Widget _saveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppTheme.space4, AppTheme.space3,
          AppTheme.space4, AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _dirty
                      ? 'Unsaved changes'
                      : (_essentialsDone
                          ? 'Ready to save'
                          : 'Tap a mood, say one line — that is enough'),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _dirty
                        ? AppTheme.accentLight
                        : (_essentialsDone
                            ? AppTheme.success
                            : AppTheme.textSecondary),
                  ),
                ),
                Text(
                  '$_filledCount of $_totalCount filled · all optional',
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          SizedBox(
            width: 148,
            child: SacredButton(
              label: _existingEntryId != null ? 'Update' : 'Save entry',
              icon: Icons.check_rounded,
              loading: _isSaving,
              onTap: _isSaving ? null : _saveEntry,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── reading ───────────────────────────

  /// Past entries are read, not edited. Rendering them as greyed-out text
  /// fields made every empty box shout "(Empty)" at someone revisiting a good
  /// day; this shows what was written and nothing else.
  List<Widget> _readingView() {
    const moodLabels = {
      1: 'Restless',
      2: 'Heavy',
      3: 'Neutral',
      4: 'Calm',
      5: 'Joyful'
    };

    final chips = <(String, List<String>)>[
      ('Energy', _energy.map((e) => JournalOptions.labelFor(JournalOptions.energyLevels, e)).toList()),
      ('Practices', _practices.map((e) => JournalOptions.labelFor(JournalOptions.practices, e)).toList()),
      ('What shaped the day', _influences.map((e) => JournalOptions.labelFor(JournalOptions.influences, e)).toList()),
      ('Went right', _habits.map((e) => JournalOptions.labelFor(JournalOptions.habits, e)).toList()),
      ('Pulled at you', _challenges.map((e) => JournalOptions.labelFor(JournalOptions.challenges, e)).toList()),
      (
        'Craft',
        _craft
            .map((e) => Professions.habitLabel(
                context.read<AuthProvider>().profile?.profession ?? 'other', e))
            .toList()
      ),
    ].where((e) => e.$2.isNotEmpty).toList();

    final written = <(String, String)>[
      ('About the day', _bestMomentCtrl.text),
      ('A habit being built', _newHabitCtrl.text),
      ('The smallest step', _tinyStepCtrl.text),
      ('A habit being let go', _badHabitCtrl.text),
      ('Where this is going', _visualizationCtrl.text),
      ('A thought that pulled down', _triggerThoughtCtrl.text),
      ('A kinder answer', _triggerResponseCtrl.text),
      ('Kept telling myself', _affirmationsCtrl.text),
      ('A line that stayed', _shivBabaLineCtrl.text),
      ('Tonight\'s plan', _nightRoutineCtrl.text),
      ('Last night\'s sleep', _sleepReflectionCtrl.text),
    ].where((e) => e.$2.trim().isNotEmpty).toList();

    final checkIn = widget.entry?.checkIn ?? const <String, String>{};

    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.space4),
        decoration: BoxDecoration(
          color: AppTheme.bgCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 15, color: AppTheme.textMuted),
            const SizedBox(width: AppTheme.space2),
            const Expanded(
              child: Text(
                'A finished day. Kept exactly as you wrote it.',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: AppTheme.textMuted),
              ),
            ),
            Text(
              moodLabels[_selectedMood] ?? '',
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryLight),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppTheme.space5),

      if (chips.isNotEmpty) ...[
        for (final (label, values) in chips) ...[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted),
          ),
          const SizedBox(height: AppTheme.space2),
          Wrap(
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space2,
            children: values
                .map((v) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(v,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12.5,
                              color: AppTheme.textSecondary)),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppTheme.space5),
        ],
      ],

      for (final (label, value) in written) ...[
        _ReadBlock(label: label, value: value),
        const SizedBox(height: AppTheme.space4),
      ],

      if (checkIn.isNotEmpty) ...[
        const SizedBox(height: AppTheme.space2),
        const Text(
          'From that day\'s check-in',
          style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: AppTheme.space3),
        for (final e in checkIn.entries) ...[
          _ReadBlock(label: _checkInLabel(e.key), value: e.value),
          const SizedBox(height: AppTheme.space4),
        ],
      ],

      if (chips.isEmpty && written.isEmpty && checkIn.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: AppTheme.space10),
          child: Center(
            child: Text(
              'Nothing was written on this day.',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: AppTheme.textMuted),
            ),
          ),
        ),
    ];
  }

  /// Check-in answers are stored under question ids; a past entry should not
  /// show `letting_go` as a heading.
  String _checkInLabel(String id) =>
      CheckInLabels.known[id] ?? id.replaceAll('_', ' ');
}

/// Headings for stored check-in answers. Kept here rather than derived from
/// today's rotating question set, because an entry from six months ago may hold
/// an id that is no longer in rotation.
class CheckInLabels {
  static const known = <String, String>{
    'day': 'How the day was',
    'body': 'How the body was',
    'family': 'How everyone at home was',
    'exciting': 'Wanted to tell someone',
    'plan': 'The plan for tomorrow',
    'new_people': 'Someone new',
    'skill': 'Something learned',
    'adventure': 'Something different',
    'proud': 'Quietly proud of',
    'heavy': 'Sitting heavy',
    'grateful': 'Grateful for',
    'kindness': 'Kindness',
    'letting_go': 'Ready to put down',
    'someone': 'On my mind',
    'unsaid': 'Left unsaid',
  };
}

// ─────────────────────────── pieces ───────────────────────────

/// A numbered step card. The number is what turns a wall of fields into a
/// short, obviously-finishable sequence.
class _Card extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final Widget child;

  const _Card({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryLight),
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          child,
        ],
      ),
    );
  }
}

/// A collapsed optional section. Closed, it is one line; open, it is a small
/// group of related questions rather than another undifferentiated run of boxes.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String summary;
  final bool open;
  final int filled;
  final int total;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.title,
    required this.summary,
    required this.open,
    required this.filled,
    required this.total,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: open ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space4),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.primaryLight),
                    const SizedBox(width: AppTheme.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                          Text(
                            summary,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11.5,
                                color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (filled > 0)
                      Container(
                        margin: const EdgeInsets.only(right: AppTheme.space2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPill),
                        ),
                        child: Text(
                          '$filled/$total',
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success),
                        ),
                      ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.expand_more_rounded,
                          size: 20, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0,
                  AppTheme.space4, AppTheme.space4),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }
}

/// One writing field, with the microphone always beside it.
class _WriteField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String hint;
  final int lines;
  final bool emphasised;

  const _WriteField({
    required this.controller,
    required this.hint,
    this.label,
    this.lines = 1,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.space2),
          ],
          TextField(
            controller: controller,
            maxLines: lines,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: AppTheme.textMuted),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(14, 13, 4, 13),
              suffixIcon:
                  VoiceInputButton(controller: controller, iconSize: 19),
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
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One answered question, rendered for reading.
class _ReadBlock extends StatelessWidget {
  final String label;
  final String value;

  const _ReadBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted),
        ),
        const SizedBox(height: 5),
        Text(
          value.trim(),
          style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14.5,
              height: 1.55,
              color: AppTheme.textPrimary),
        ),
      ],
    );
  }
}
