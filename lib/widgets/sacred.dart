import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme/app_theme.dart';

/// Shared visual language for Brahma Journal.
///
/// The screens used to each roll their own gradient container, card border and
/// button, so nothing quite lined up and the app read as a set of prototypes.
/// These are the pieces every redesigned screen composes from.

// ─────────────────────────── motifs ───────────────────────────

enum SacredMotif { mandala, lotus, om }

/// A hand-authored vector motif, tinted to any colour.
class Motif extends StatelessWidget {
  final SacredMotif motif;
  final double size;
  final Color color;
  final double opacity;

  const Motif(
    this.motif, {
    super.key,
    required this.size,
    this.color = Colors.white,
    this.opacity = 1,
  });

  static const _paths = {
    SacredMotif.mandala: 'assets/art/mandala.svg',
    SacredMotif.lotus: 'assets/art/lotus.svg',
    SacredMotif.om: 'assets/art/om.svg',
  };

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SvgPicture.asset(
        _paths[motif]!,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

/// Slowly rotating mandala. Used behind hero areas.
///
/// One rotation per two minutes — fast enough to feel alive when you look for
/// it, slow enough never to compete with the content.
class BreathingMandala extends StatefulWidget {
  final double size;
  final Color color;
  final double opacity;

  const BreathingMandala({
    super.key,
    required this.size,
    this.color = AppTheme.primaryLight,
    this.opacity = 0.12,
  });

  @override
  State<BreathingMandala> createState() => _BreathingMandalaState();
}

class _BreathingMandalaState extends State<BreathingMandala>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.rotate(
          angle: _ctrl.value * 2 * math.pi,
          child: child,
        ),
        // Built once and rotated, rather than rebuilt every frame.
        child: Motif(
          SacredMotif.mandala,
          size: widget.size,
          color: widget.color,
          opacity: widget.opacity,
        ),
      ),
    );
  }
}

// ─────────────────────────── backdrop ───────────────────────────

/// The layered background every redesigned screen sits on: a vertical gradient,
/// two coloured light sources, and an optional mandala watermark.
class SacredBackdrop extends StatelessWidget {
  final Widget child;
  final bool showMandala;

  const SacredBackdrop({super.key, required this.child, this.showMandala = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: Stack(
        // Every other child here is Positioned, so without this the Stack sizes
        // itself to `child` alone. On a screen whose content is shorter than the
        // viewport — sign-in, forgot-password — that collapsed the gradient to
        // the height of the form and left the scaffold's flat black showing
        // below it. Expanding pins the backdrop to the full screen and puts the
        // bottom glow where it belongs.
        fit: StackFit.expand,
        children: [
          // Warm light from the top-right, cool from the bottom-left. Two
          // sources stop the flat gradient reading as a plain dark rectangle.
          Positioned(
            top: -160,
            right: -120,
            child: _GlowOrb(color: AppTheme.primary.withValues(alpha: 0.30), size: 360),
          ),
          Positioned(
            bottom: -180,
            left: -140,
            child: _GlowOrb(color: AppTheme.accent.withValues(alpha: 0.10), size: 380),
          ),
          if (showMandala)
            Positioned(
              top: -70,
              right: -70,
              child: BreathingMandala(size: 260, opacity: 0.10),
            ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

// ─────────────────────────── surfaces ───────────────────────────

/// Frosted card. The blur is what separates this from the flat filled boxes the
/// app used before — content behind it stays faintly visible, which is what
/// makes a dark UI feel layered rather than papered over.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;
  final double radius;
  final bool highlighted;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.space4),
    this.onTap,
    this.tint,
    this.radius = AppTheme.radiusLg,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = highlighted
        ? AppTheme.primary.withValues(alpha: 0.55)
        : AppTheme.border.withValues(alpha: 0.85);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: (tint ?? AppTheme.bgCard).withValues(alpha: 0.72),
          child: InkWell(
            onTap: onTap,
            splashColor: AppTheme.primary.withValues(alpha: 0.10),
            highlightColor: AppTheme.primary.withValues(alpha: 0.05),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: borderColor),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.01),
                  ],
                ),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section heading with a small motif — used instead of a bare bold Text so
/// sections read as deliberate rather than as leftover labels.
class SectionHeading extends StatelessWidget {
  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;
  final IconData? icon;

  const SectionHeading({
    super.key,
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppTheme.primaryLight),
          const SizedBox(width: AppTheme.space2),
        ],
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        if (trailingLabel != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailingLabel!,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────── controls ───────────────────────────

/// The app's primary action. One button definition instead of the several
/// slightly different gradient containers that were inlined per screen.
class SacredButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  final bool secondary;
  final bool expand;

  const SacredButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.loading = false,
    this.secondary = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: secondary ? AppTheme.primaryLight : Colors.white),
            const SizedBox(width: AppTheme.space2),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: secondary ? AppTheme.primaryLight : Colors.white,
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.space4,
            horizontal: AppTheme.space6,
          ),
          decoration: BoxDecoration(
            gradient: secondary ? null : AppTheme.primaryGradient,
            color: secondary ? Colors.white.withValues(alpha: 0.04) : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: secondary
                ? Border.all(color: AppTheme.primary.withValues(alpha: 0.45))
                : null,
            boxShadow: secondary || !enabled ? null : AppTheme.glow(AppTheme.primary),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Screen header used across the redesigned screens: back affordance, centred
/// title, optional action. Replaces four subtly different inline AppBar rows.
class SacredAppBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? action;
  final String? subtitle;

  const SacredAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.action,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.space2, AppTheme.space3, AppTheme.space4, AppTheme.space2),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimary, size: 18),
              onPressed: onBack,
            )
          else
            const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 44, child: action ?? const SizedBox()),
        ],
      ),
    );
  }
}
