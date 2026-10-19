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
  });

  final bool hasEntry;
  final VoidCallback onJournal;
  final VoidCallback onMeditate;

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
                    hasEntry ? 'A MOMENT, KEPT' : 'A LITTLE SPACE FOR YOU',
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
                  : 'How are you,\nreally?',
              style: const TextStyle(
                  fontSize: 32,
                  height: 1.12,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Text(
              hasEntry
                  ? 'Your entry is saved. Return to it whenever you need.'
                  : 'One honest thought is enough. Take a moment to make today yours.',
              style: const TextStyle(
                  color: AppTheme.textSecondary, height: 1.5, fontSize: 15)),
          const SizedBox(height: 24),
          SacredButton(
              label: hasEntry ? 'Return to your journal' : 'Write a little',
              icon: Icons.edit_note_rounded,
              onTap: onJournal),
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
