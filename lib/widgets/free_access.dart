import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import 'sacred.dart';

/// Says that everything is free. It does not say for how long.
///
/// This was a live countdown against a fixed end date, ticking once a minute,
/// with a progress bar filling towards the moment access expired. All of that
/// is gone on purpose. A countdown is a promise that something is about to be
/// taken away, and it kept that promise on a schedule nobody revisited — a
/// member who opened the app in week eleven was told to hurry up by a deadline
/// set in a constant months earlier.
///
/// Now it is a plain statement of the current state, and the state only changes
/// when [AppConstants.paymentsEnabled] is flipped by hand.
class FreeAccessBanner extends StatelessWidget {
  final bool compact;
  const FreeAccessBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!AppConstants.isFreeAccessActive) return const SizedBox.shrink();

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space3, vertical: AppTheme.space1 + 2),
        decoration: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_giftcard_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            const Text(
              'Everything free',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      tint: AppTheme.accent.withValues(alpha: 0.10),
      padding: const EdgeInsets.all(AppTheme.space4),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              boxShadow: AppTheme.glow(AppTheme.accent, strength: 0.30),
            ),
            child: const Icon(Icons.card_giftcard_rounded,
                size: 23, color: Colors.white),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Everything is free',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Every feature, no card, no catch. Take as long as you need — '
                  'nothing here is counting down.',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    height: 1.35,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on the signup form in place of the plan picker while billing is off.
class FreeAccessNotice extends StatelessWidget {
  const FreeAccessNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded,
              size: 22, color: AppTheme.accentLight),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Free for everyone right now',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'No payment, no card details, no trial clock.',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    height: 1.35,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
