import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import 'sacred.dart';

/// Live countdown to the end of the free-access window.
///
/// Ticks once a minute rather than once a second: below a day the seconds would
/// be noise, and a per-second rebuild of the dashboard costs battery for no
/// benefit. Inside the last 24 hours it switches to hours so the urgency is
/// real rather than a static number.
class FreeAccessBanner extends StatefulWidget {
  final bool compact;
  const FreeAccessBanner({super.key, this.compact = false});

  @override
  State<FreeAccessBanner> createState() => _FreeAccessBannerState();
}

class _FreeAccessBannerState extends State<FreeAccessBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String remainingLabel() {
    final left = AppConstants.freeAccessUntil.difference(DateTime.now().toUtc());
    if (left.isNegative) return 'Free access has ended';
    if (left.inDays >= 1) {
      final d = left.inDays;
      return '$d ${d == 1 ? 'day' : 'days'} left';
    }
    final h = left.inHours;
    if (h >= 1) return '$h ${h == 1 ? 'hour' : 'hours'} left';
    return 'Ends within the hour';
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConstants.isFreeAccessActive) return const SizedBox.shrink();

    final left = AppConstants.freeAccessUntil.difference(DateTime.now().toUtc());
    final total = const Duration(days: 92).inSeconds;
    final progress = (1 - (left.inSeconds / total)).clamp(0.0, 1.0);

    if (widget.compact) {
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
            Text(
              'Free · ${remainingLabel()}',
              style: const TextStyle(
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
                Row(
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
                    const SizedBox(width: AppTheme.space2),
                    Text(
                      remainingLabel(),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Every feature, no card, no catch. Build the habit while it lasts.',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    height: 1.35,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
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
                Text(
                  'No payment, no card details. ${_FreeAccessBannerState.remainingLabel()}.',
                  style: const TextStyle(
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
