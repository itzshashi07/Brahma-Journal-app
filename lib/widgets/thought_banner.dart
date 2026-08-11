import 'package:flutter/material.dart';
import '../core/constants/thoughts_365.dart';
import '../core/theme/app_theme.dart';
import 'sacred.dart';

/// The thought of the day, on the dashboard.
///
/// It used to be a flat purple box with an italic quote and no indication of
/// what it was for — indistinguishable from the decorative banner every other
/// app puts above the fold, and skipped just as quickly. This version gives it
/// the weight of a card (motif, date, deliberate typography) and, more
/// importantly, a way in: "What to do with this" explains the practice in
/// plain words, because a quote nobody knows how to use is decoration.
class ThoughtBanner extends StatelessWidget {
  final String text;

  /// Admins can rewrite the day's thought; everyone else sees no edit affordance.
  final VoidCallback? onEdit;

  const ThoughtBanner({super.key, required this.text, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = Thoughts365.dayOfYear(now);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4C1D95), Color(0xFF6D28D9), Color(0xFF9333EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Texture behind the words, bleeding off the edge — the card should
            // feel printed rather than filled.
            const Positioned(
              right: -46,
              top: -46,
              child: Motif(
                SacredMotif.mandala,
                size: 170,
                color: Colors.white,
                opacity: 0.12,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.space5, AppTheme.space5, AppTheme.space5, AppTheme.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_twilight_rounded,
                          size: 16, color: Colors.white70),
                      const SizedBox(width: AppTheme.space2),
                      const Text(
                        'THOUGHT FOR TODAY',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.white70,
                        ),
                      ),
                      const Spacer(),
                      if (onEdit != null)
                        GestureDetector(
                          onTap: onEdit,
                          child: const Padding(
                            padding: EdgeInsets.only(left: AppTheme.space2),
                            child: Icon(Icons.edit_outlined,
                                size: 17, color: Colors.white70),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space4),
                  // No italics: italic at this length is harder to read, and the
                  // quote mark already says it is a quotation.
                  Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Row(
                    children: [
                      Text(
                        'Day $day of 365',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          color: Colors.white54,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showGuidance(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space3, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.help_outline_rounded, size: 15),
                        label: const Text(
                          ThoughtGuidance.title,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuidance(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Sized to its content rather than to a fixed fraction of the screen: a
      // draggable sheet at 0.8 left a third of it empty under the last line,
      // which reads as something failed to load.
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: Container(
            margin: const EdgeInsets.all(AppTheme.space3),
            padding: const EdgeInsets.all(AppTheme.space5),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: AppTheme.border),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text(
                ThoughtGuidance.title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              const Text(
                ThoughtGuidance.intro,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13.5,
                  height: 1.6,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              // Today's line repeated here, so the steps have something to point
              // at without the reader closing the sheet to check.
              Container(
                padding: const EdgeInsets.all(AppTheme.space4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.28)),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              ...ThoughtGuidance.steps.indexed.map((entry) {
                final (i, step) = entry;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.$1,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              step.$2,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12.5,
                                height: 1.55,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Container(
                padding: const EdgeInsets.all(AppTheme.space3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border:
                      Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                ),
                child: const Text(
                  ThoughtGuidance.note,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11.5,
                    height: 1.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
