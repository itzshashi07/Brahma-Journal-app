import 'package:flutter/material.dart';
import '../core/constants/affirmation_backgrounds.dart';
import '../core/theme/app_theme.dart';
import 'sacred.dart';

/// An affirmation on its own background.
///
/// A line sitting on a plain card reads as a to-do item. The same line on a
/// full-bleed gradient with a mandala behind it reads as something to sit with
/// — and it is shareable, which is how these spread.
class AffirmationCard extends StatelessWidget {
  final String text;
  final String? backgroundId;
  final VoidCallback? onTapBackground;
  final double height;

  const AffirmationCard({
    super.key,
    required this.text,
    this.backgroundId,
    this.onTapBackground,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundId != null
        ? AffirmationBackgrounds.byId(backgroundId)
        : AffirmationBackgrounds.forText(text);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bg.gradient,
            begin: bg.begin,
            end: bg.end,
          ),
        ),
        child: Stack(
          children: [
            // Motif bleeds off the corner rather than sitting centred — it
            // should feel like texture behind the words, not a logo above them.
            Positioned(
              right: -40,
              bottom: -40,
              child: Motif(
                SacredMotif.mandala,
                size: 190,
                color: Colors.white,
                opacity: 0.13,
              ),
            ),
            Positioned(
              left: -24,
              top: -24,
              child: Motif(
                SacredMotif.lotus,
                size: 110,
                color: Colors.white,
                opacity: 0.10,
              ),
            ),
            // Slight darkening so white text stays legible on the lighter
            // gradients without dulling the colour.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.28),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '❝',
                    style: TextStyle(
                        fontSize: 26, color: Colors.white70, height: 1),
                  ),
                  const SizedBox(height: AppTheme.space2),
                  Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black38, blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (onTapBackground != null)
              Positioned(
                right: AppTheme.space3,
                top: AppTheme.space3,
                child: GestureDetector(
                  onTap: onTapBackground,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.palette_outlined,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Background chooser.
class BackgroundPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const BackgroundPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    String? selected,
    required ValueChanged<String> onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(AppTheme.space4),
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a background',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space2),
            const Text(
              'All free, always.',
              style: TextStyle(
                  fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: AppTheme.space4),
            BackgroundPicker(
              selected: selected,
              onChanged: (id) {
                onChanged(id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.space3,
      runSpacing: AppTheme.space3,
      alignment: WrapAlignment.center,
      children: AffirmationBackgrounds.all.map((b) {
        final isOn = b.id == selected;
        return GestureDetector(
          onTap: () => onChanged(b.id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: b.gradient, begin: b.begin, end: b.end),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isOn ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: isOn
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(height: 5),
              Text(
                b.name,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    color: AppTheme.textMuted),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
