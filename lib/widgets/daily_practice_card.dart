import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'sacred.dart';

/// One clear starting point before the full feature library.
class DailyPracticeCard extends StatelessWidget {
  const DailyPracticeCard({
    super.key,
    required this.hasEntry,
    required this.onJournal,
    required this.onMeditate,
    this.onReset,
    this.hasPendingReset = false,
  });

  final bool hasEntry;
  final VoidCallback onJournal;
  final VoidCallback onMeditate;
  final VoidCallback? onReset;
  final bool hasPendingReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF30214E), Color(0xFF1D1A35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF594376)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(hasEntry ? Icons.check_circle_outline : Icons.wb_twilight,
                size: 18, color: const Color(0xFFE7CDA5)),
            const SizedBox(width: 8),
            Flexible(
                child: Text(
                    hasEntry ? 'A MOMENT, KEPT' : 'YOUR TWO-MINUTE RESET',
                    style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE7CDA5)))),
          ]),
          const SizedBox(height: 16),
          Text(
              hasEntry
                  ? 'You showed up\nfor yourself.'
                  : 'A lot on\nyour mind?',
              style: const TextStyle(
                  fontSize: 32,
                  height: 1.12,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Text(
              hasEntry
                  ? 'Your entry is saved. Take another short pause whenever you need.'
                  : 'Name what is taking up space. Choose one small next step. That is enough for today.',
              style: const TextStyle(
                  color: AppTheme.textSecondary, height: 1.5, fontSize: 15)),
          const SizedBox(height: 24),
          SacredButton(
              label: onReset == null
                  ? (hasEntry ? 'Return to your journal' : 'Write a little')
                  : (hasPendingReset ? 'Continue my reset' : 'Take a 2-minute reset'),
              icon: Icons.edit_note_rounded,
              onTap: onReset ?? onJournal),
          if (onReset != null) TextButton(onPressed: onJournal,
              child: Text(hasEntry ? 'Open my journal' : 'I would rather write')),
          const SizedBox(height: 8),
          Center(
              child: TextButton.icon(
                  onPressed: onMeditate,
                  icon: const Icon(Icons.air_rounded, size: 18),
                  label: const Text('Or take a breathing break',
                      textAlign: TextAlign.center))),
        ],
      ),
    );
  }
}
