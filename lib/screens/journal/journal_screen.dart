import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/journal_entry.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../widgets/voice_input_button.dart';
import '../../widgets/journal_chips.dart';
import '../../core/constants/journal_options.dart';

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
    _loadToday();
  }

  Future<void> _loadToday() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final journal = context.read<JournalProvider>();
    if (auth.user != null && journal.entries.isEmpty) {
      await journal.loadEntries(auth.user!.uid);
    }
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
      _sleepReflectionCtrl.text = target.sleepReflection;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveEntry() async {
    if (_isReadOnly) return;
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() => _isSaving = true);
    try {
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
        createdAt: widget.entry?.createdAt ?? DateTime.now(),
      );
      final id = await context.read<JournalProvider>().saveEntry(entry, existingId: _existingEntryId);
      setState(() => _existingEntryId = id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Journal entry saved!', style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _newHabitCtrl.dispose(); _tinyStepCtrl.dispose(); _badHabitCtrl.dispose();
    _affirmationsCtrl.dispose(); _visualizationCtrl.dispose(); _nightRoutineCtrl.dispose();
    _triggerThoughtCtrl.dispose(); _triggerResponseCtrl.dispose(); _bestMomentCtrl.dispose();
    _shivBabaLineCtrl.dispose(); _sleepReflectionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalProvider>();
    final entryDate = widget.entry?.createdAt ?? DateTime.now();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        _isReadOnly ? '📖 Past Reflection' : '📔 Daily Journal',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (!_isReadOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          '🔥 ${journal.streak} day',
                          style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      const SizedBox(width: 44),
                  ],
                ),
              ),

              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date display
                        Center(
                          child: Text(
                            AppDateUtils.formatDate(entryDate),
                            style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        ),
                        if (_isReadOnly) ...[
                          const SizedBox(height: 6),
                          const Center(
                            child: Card(
                              color: Color(0xFF1E1E38),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Text(
                                  '🔒 Read-Only (Past entry cannot be edited)',
                                  style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ),
                        ] else if (_existingEntryId != null) ...[
                          const SizedBox(height: 4),
                          const Center(
                            child: Text('✏️ Editing today\'s entry', style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF10B981), fontSize: 12)),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Mood Section
                        _SectionHeader(icon: Icons.sentiment_satisfied_alt_outlined, title: _isReadOnly ? 'Mood of the day' : 'How are you feeling today?'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [1, 2, 3, 4, 5].map((val) {
                            final label = {1: 'Restless', 2: 'Heavy', 3: 'Neutral', 4: 'Calm', 5: 'Joyful'}[val]!;
                            final activeColor = {
                              1: const Color(0xFFEF4444),
                              2: const Color(0xFFF59E0B),
                              3: const Color(0xFF6B7280),
                              4: const Color(0xFF3B82F6),
                              5: const Color(0xFF10B981)
                            }[val]!;
                            final isSelected = _selectedMood == val;
                            return GestureDetector(
                              onTap: _isReadOnly ? null : () => setState(() => _selectedMood = val),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? activeColor.withOpacity(0.15) : AppTheme.bgCard,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? activeColor : const Color(0xFF2D2D4E),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                    color: isSelected ? activeColor : AppTheme.textMuted,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Journal Fields
                        // A line to open with. Chosen by day so it stays the
                        // same all day — a prompt that changes on every rebuild
                        // reads as decoration, not as something said to you.
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.format_quote_rounded, size: 18, color: AppTheme.accentLight),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  JournalPrompts.forToday(),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit', fontSize: 13, height: 1.5,
                                    fontStyle: FontStyle.italic, color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (!_isReadOnly) ...[
                          ChipGroupField(
                            label: 'Energy today',
                            singleChoice: true,
                            options: JournalOptions.energyLevels,
                            selected: _energy,
                            onChanged: (v) => setState(() => _energy = v),
                          ),
                          const SizedBox(height: 22),
                          ChipGroupField(
                            label: 'Practices',
                            hint: 'tap any',
                            options: JournalOptions.practices,
                            selected: _practices,
                            onChanged: (v) => setState(() => _practices = v),
                          ),
                          const SizedBox(height: 22),
                          ChipGroupField(
                            label: 'What shaped today',
                            hint: 'tap any',
                            options: JournalOptions.influences,
                            selected: _influences,
                            onChanged: (v) => setState(() => _influences = v),
                          ),
                          const SizedBox(height: 22),
                          ChipGroupField(
                            label: 'Things that went right',
                            hint: 'tap any',
                            options: JournalOptions.habits,
                            selected: _habits,
                            onChanged: (v) => setState(() => _habits = v),
                          ),
                          const SizedBox(height: 22),
                          ChipGroupField(
                            label: 'What pulled at you',
                            hint: 'tap any',
                            options: JournalOptions.challenges,
                            selected: _challenges,
                            onChanged: (v) => setState(() => _challenges = v),
                          ),
                          const SizedBox(height: 26),
                          const Divider(color: AppTheme.border),
                          const SizedBox(height: 20),
                          const Text(
                            'Write more, if you want to',
                            style: TextStyle(
                              fontFamily: 'Outfit', fontSize: 14,
                              fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Every box below is optional.',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 16),
                        ],

                        _JournalField(
                          icon: Icons.spa_outlined, title: 'New Habit to Build',
                          hint: _isReadOnly ? '(Empty)' : 'What new habit are you working on?',
                          controller: _newHabitCtrl,
                          readOnly: _isReadOnly,
                        ),
                        _JournalField(
                          icon: Icons.directions_walk_outlined, title: 'Tiny Step Today',
                          hint: _isReadOnly ? '(Empty)' : 'What small step will you take today?',
                          controller: _tinyStepCtrl,
                          readOnly: _isReadOnly,
                        ),
                        _JournalField(
                          icon: Icons.highlight_off_outlined, title: 'Bad Habit to Break',
                          hint: _isReadOnly ? '(Empty)' : 'What habit are you breaking?',
                          controller: _badHabitCtrl,
                          readOnly: _isReadOnly,
                        ),
                        _JournalField(
                          icon: Icons.auto_awesome_outlined, title: 'Affirmations',
                          hint: _isReadOnly ? '(Empty)' : 'Write your affirmations for today...',
                          controller: _affirmationsCtrl, maxLines: 3,
                          readOnly: _isReadOnly,
                        ),
                        _JournalField(
                          icon: Icons.remove_red_eye_outlined, title: 'Visualization',
                          hint: _isReadOnly ? '(Empty)' : 'Describe your ideal day / vision...',
                          controller: _visualizationCtrl, maxLines: 3,
                          readOnly: _isReadOnly,
                        ),
                        _JournalField(
                          icon: Icons.bedtime_outlined, title: 'Night Routine',
                          hint: _isReadOnly ? '(Empty)' : 'What is your plan for tonight?',
                          controller: _nightRoutineCtrl, maxLines: 2,
                          readOnly: _isReadOnly,
                        ),
                        _JournalField(
                          icon: Icons.psychology_outlined, title: 'Trigger Thought',
                          hint: _isReadOnly ? '(Empty)' : 'What thought triggered negativity?',
                          controller: _triggerThoughtCtrl,
                          readOnly: _isReadOnly,
                        ),
                        _JournalField(
                          icon: Icons.lightbulb_outline, title: 'Better Response',
                          hint: _isReadOnly ? '(Empty)' : 'How could you have responded better?',
                          controller: _triggerResponseCtrl, maxLines: 2,
                          readOnly: _isReadOnly,
                        ),
                        _JournalField(
                          icon: Icons.star_border_outlined, title: 'Best Moment of the Day',
                          hint: _isReadOnly ? '(Empty)' : 'What was the best thing that happened?',
                          controller: _bestMomentCtrl, maxLines: 2,
                          readOnly: _isReadOnly,
                        ),
                        _JournalField(
                          // Was "Shiv Baba's Line", which only makes sense
                          // inside one tradition. Reworded so a member of any
                          // faith — or none — can answer it honestly.
                          icon: Icons.brightness_high_outlined, title: 'A line that stayed with you',
                          hint: _isReadOnly ? '(Empty)' : 'From scripture, a book, a talk, a song — anything that landed today...',
                          controller: _shivBabaLineCtrl, maxLines: 2,
                          readOnly: _isReadOnly,
                        ),
                        _JournalField(
                          icon: Icons.nights_stay_outlined, title: 'Sleep Reflection',
                          hint: _isReadOnly ? '(Empty)' : 'How was your sleep? Any dreams?',
                          controller: _sleepReflectionCtrl, maxLines: 2,
                          readOnly: _isReadOnly,
                        ),

                        const SizedBox(height: 24),

                        // Save Button (Only show if editable)
                        if (!_isReadOnly) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _isSaving ? null : _saveEntry,
                                  child: Center(
                                    child: _isSaving
                                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : Text(
                                            _existingEntryId != null ? '✏️ Update Entry' : '💾 Save Entry',
                                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _JournalField extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final bool readOnly;

  const _JournalField({
    required this.icon, required this.title, required this.hint,
    required this.controller, this.maxLines = 1, this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          style: TextStyle(
            color: readOnly ? AppTheme.textSecondary : AppTheme.textPrimary,
            fontFamily: 'Outfit',
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: readOnly,
            fillColor: readOnly ? const Color(0xFF1E1E38).withOpacity(0.3) : null,
            enabledBorder: readOnly
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: const Color(0xFF2D2D4E).withOpacity(0.5)),
                  )
                : null,
            suffixIcon: readOnly
                ? null
                : VoiceInputButton(controller: controller, iconSize: 18),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
