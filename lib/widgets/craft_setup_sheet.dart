import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/professions.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/profile_service.dart';
import 'sacred.dart';

/// Naming the thing you are trying to get good at.
///
/// Three questions, all on one screen, all changeable later. It is deliberately
/// not part of signup: asking somebody their life's aim before they have seen
/// the app is a question they answer carelessly or not at all. This appears
/// where it earns its keep — at the top of an empty consistency chart, as the
/// thing standing between them and the chart being useful.
class CraftSetupSheet extends StatefulWidget {
  const CraftSetupSheet({super.key});

  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const CraftSetupSheet(),
      );

  @override
  State<CraftSetupSheet> createState() => _CraftSetupSheetState();
}

class _CraftSetupSheetState extends State<CraftSetupSheet> {
  final _aimCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  String? _profession;
  int _target = Professions.defaultWeeklyTarget;
  bool _saving = false;

  /// The member's own checklist items, edited locally and written on save so
  /// backing out of the sheet leaves the stored list untouched.
  List<CraftHabit> _custom = const [];

  @override
  void initState() {
    super.initState();
    final p = context.read<AuthProvider>().profile;
    _profession = Professions.isKnown(p?.profession) ? p!.profession : null;
    _aimCtrl.text = p?.aim ?? '';
    _target = p?.craftWeeklyTarget ?? Professions.defaultWeeklyTarget;
    _custom = List.of(p?.customHabits ?? const []);
  }

  @override
  void dispose() {
    _aimCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _addCustom() {
    final label = _customCtrl.text.trim();
    if (label.isEmpty || _custom.length >= Professions.maxCustomHabits) return;

    // Same item twice is always a mistake, and two identical rows in a
    // checklist make it impossible to know which one you already ticked.
    final already = _custom.any(
        (h) => h.label.toLowerCase() == label.toLowerCase());
    if (already) {
      _customCtrl.clear();
      return;
    }

    setState(() {
      _custom = [..._custom, CraftHabit.custom(label: label)];
      _customCtrl.clear();
    });
  }

  /// Removes an item from the checklist going forward.
  ///
  /// Days already ticked keep their id in `craftDone`, so history and every
  /// streak computed from it stay exactly as they were — deleting a habit is
  /// not meant to be a way of rewriting the past.
  void _removeCustom(String id) {
    setState(() => _custom = _custom.where((h) => h.id != id).toList());
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    if (profile == null || _profession == null) return;

    setState(() => _saving = true);
    try {
      await ProfileService().saveProfile(profile.copyWith(
        profession: _profession,
        aim: _aimCtrl.text.trim(),
        craftWeeklyTarget: _target,
        customHabits: _custom,
      ));
      await auth.refreshProfile();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = _profession == null ? null : Professions.byId(_profession);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
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
                const Text(
                  'What are you working on?',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The journal already knows how you felt. Tell it what you are '
                  'trying to get good at, and it can tell you whether you are '
                  'actually doing it.',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppTheme.textMuted),
                ),
                const SizedBox(height: AppTheme.space5),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppTheme.space2,
                          runSpacing: AppTheme.space2,
                          children: Professions.all.map((p) {
                            final on = _profession == p.id;
                            return GestureDetector(
                              onTap: () => setState(() => _profession = p.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 13, vertical: 9),
                                decoration: BoxDecoration(
                                  color: on
                                      ? Professions.accentFor(p.id)
                                          .withValues(alpha: 0.20)
                                      : Colors.white.withValues(alpha: 0.045),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusPill),
                                  border: Border.all(
                                    color: on
                                        ? Professions.accentFor(p.id)
                                        : AppTheme.border,
                                    width: on ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(p.emoji,
                                        style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      p.label,
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12.5,
                                        fontWeight: on
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: on
                                            ? AppTheme.textPrimary
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        if (chosen != null) ...[
                          const SizedBox(height: AppTheme.space5),
                          const Text(
                            'What are you aiming for?',
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'One line, in your words. You will see it every time '
                            'you open your progress.',
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11.5,
                                color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: AppTheme.space3),
                          TextField(
                            controller: _aimCtrl,
                            maxLines: 2,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: chosen.aimHint,
                              hintStyle: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  color: AppTheme.textMuted),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.04),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                                borderSide:
                                    const BorderSide(color: AppTheme.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                                borderSide:
                                    const BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.space5),
                          const Text(
                            'How many days a week?',
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Pick one you can keep on a bad week, not a good one.',
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11.5,
                                color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: AppTheme.space3),
                          Row(
                            children: Professions.weeklyTargets.map((t) {
                              final on = _target == t;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _target = t),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: AppTheme.space3),
                                    decoration: BoxDecoration(
                                      color: on
                                          ? AppTheme.primary
                                              .withValues(alpha: 0.20)
                                          : Colors.white
                                              .withValues(alpha: 0.045),
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMd),
                                      border: Border.all(
                                        color: on
                                            ? AppTheme.primary
                                            : AppTheme.border,
                                        width: on ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$t',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: on
                                                ? AppTheme.primaryLight
                                                : AppTheme.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          t == 7 ? 'daily' : 'days',
                                          style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 9.5,
                                              color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: AppTheme.space5),
                          const Text(
                            'Anything else you want to track?',
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'The list above is a starting point, not a verdict. '
                            'Add whatever the work actually looks like for you.',
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11.5,
                                color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: AppTheme.space3),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customCtrl,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _addCustom(),
                                  enabled: _custom.length <
                                      Professions.maxCustomHabits,
                                  style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      color: AppTheme.textPrimary),
                                  decoration: InputDecoration(
                                    hintText: _custom.length >=
                                            Professions.maxCustomHabits
                                        ? 'That is a full checklist already'
                                        : 'e.g. Read 20 pages',
                                    hintStyle: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        color: AppTheme.textMuted),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.04),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 13),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMd),
                                      borderSide: const BorderSide(
                                          color: AppTheme.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMd),
                                      borderSide: const BorderSide(
                                          color: AppTheme.border),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.space2),
                              GestureDetector(
                                onTap: _addCustom,
                                child: Container(
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd),
                                    border: Border.all(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.45)),
                                  ),
                                  child: const Icon(Icons.add_rounded,
                                      size: 20, color: AppTheme.primaryLight),
                                ),
                              ),
                            ],
                          ),
                          if (_custom.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.space3),
                            Wrap(
                              spacing: AppTheme.space2,
                              runSpacing: AppTheme.space2,
                              children: _custom
                                  .map((h) => Container(
                                        padding: const EdgeInsets.only(
                                            left: 13,
                                            right: 7,
                                            top: 8,
                                            bottom: 8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                              AppTheme.radiusPill),
                                          border: Border.all(
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.35)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${h.emoji} ${h.label}',
                                              style: const TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => _removeCustom(h.id),
                                              behavior:
                                                  HitTestBehavior.opaque,
                                              child: const Icon(
                                                  Icons.close_rounded,
                                                  size: 15,
                                                  color: AppTheme.textMuted),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],

                          const SizedBox(height: AppTheme.space5),
                          Container(
                            padding: const EdgeInsets.all(AppTheme.space3),
                            decoration: BoxDecoration(
                              color: Professions.accentFor(chosen.id)
                                  .withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                              border: Border.all(
                                  color: Professions.accentFor(chosen.id)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your journal will now ask about:',
                                  style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Professions.accentFor(chosen.id)),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  Professions.checklistFor(chosen.id, _custom)
                                      .map((h) => '${h.emoji} ${h.label}')
                                      .join('   ·   '),
                                  style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      height: 1.6,
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.space5),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Later',
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
                        label: 'Start tracking',
                        icon: Icons.check_rounded,
                        loading: _saving,
                        onTap: (_profession == null || _saving) ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
