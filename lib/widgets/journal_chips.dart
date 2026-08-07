import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Multi-select chip group for the journal.
///
/// Replaces a text field for anything that is really a choice. Twenty seconds
/// of tapping records more, more consistently, than a blank box people skip.
class ChipGroupField extends StatelessWidget {
  final String label;
  final String? hint;
  final List<(String, String, String)> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// Single-choice groups (like energy) behave as a radio set.
  final bool singleChoice;

  const ChipGroupField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.hint,
    this.singleChoice = false,
  });

  void _toggle(String id) {
    if (singleChoice) {
      onChanged(selected.contains(id) ? <String>{} : {id});
      return;
    }
    final next = Set<String>.from(selected);
    next.contains(id) ? next.remove(id) : next.add(id);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: AppTheme.space2),
            Text(
              // Says out loud that nothing here is required. A journal that
              // feels like a form is one people stop opening.
              hint ?? 'optional',
              style: const TextStyle(
                  fontFamily: 'Outfit', fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space3),
        Wrap(
          spacing: AppTheme.space2,
          runSpacing: AppTheme.space2,
          children: options.map((o) {
            final isOn = selected.contains(o.$1);
            return GestureDetector(
              onTap: () => _toggle(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space3, vertical: AppTheme.space2),
                decoration: BoxDecoration(
                  color: isOn
                      ? AppTheme.primary.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: isOn ? AppTheme.primary : AppTheme.border,
                    width: isOn ? 1.5 : 1,
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
                        fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
                        color: isOn
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
      ],
    );
  }
}
