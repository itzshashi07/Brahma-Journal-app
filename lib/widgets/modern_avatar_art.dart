import 'package:flutter/material.dart';
import '../core/constants/modern_avatars.dart';

/// Draws a [ModernAvatar].
///
/// Vector drawing rather than images: it is a few KB of code instead of a set
/// of PNGs, it stays sharp at any size, and every combination a member can
/// build renders without shipping a file for it.
class ModernAvatarArt extends StatelessWidget {
  final ModernAvatar avatar;
  final double size;

  const ModernAvatarArt({super.key, required this.avatar, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: _AvatarPainter(avatar),
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final ModernAvatar a;
  _AvatarPainter(this.a);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final skin = ModernAvatar.skinTones[a.skin];
    final hair = ModernAvatar.hairColors[a.hairColor];
    final cloth = ModernAvatar.clothesColors[a.clothes];
    final bg = ModernAvatar.backgrounds[a.bg];

    // Background
    final rect = Rect.fromLTWH(0, 0, s, s);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: bg,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    // A faint halo so the head separates from the background at small sizes.
    canvas.drawCircle(
      Offset(s * 0.5, s * 0.46),
      s * 0.33,
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );

    // Shoulders
    final shoulder = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(s * 0.16, s * 0.76, s * 0.68, s * 0.34),
        topLeft: Radius.circular(s * 0.32),
        topRight: Radius.circular(s * 0.32),
      ));
    canvas.drawPath(shoulder, Paint()..color = cloth);

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.42, s * 0.63, s * 0.16, s * 0.16),
        Radius.circular(s * 0.05),
      ),
      Paint()..color = skin,
    );

    // Head
    final headCenter = Offset(s * 0.5, s * 0.46);
    final headR = s * 0.21;
    canvas.drawCircle(headCenter, headR, Paint()..color = skin);

    // Ears
    canvas.drawCircle(
        Offset(headCenter.dx - headR, headCenter.dy + s * 0.02), s * 0.035,
        Paint()..color = skin);
    canvas.drawCircle(
        Offset(headCenter.dx + headR, headCenter.dy + s * 0.02), s * 0.035,
        Paint()..color = skin);

    _paintHair(canvas, s, headCenter, headR, hair, cloth);
    _paintFace(canvas, s, headCenter, headR);
    _paintAccessory(canvas, s, headCenter, headR, hair);
  }

  void _paintHair(Canvas canvas, double s, Offset c, double r, Color hair,
      Color cloth) {
    final p = Paint()..color = hair;

    switch (a.hair) {
      case 0: // Buzz — a thin cap following the skull
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 0.99), 3.34, 2.6, false,
            Paint()
              ..color = hair
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.045);
        break;
      case 1: // Short
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.06), 3.25, 2.8,
            true, p);
        break;
      case 2: // Side part — fuller on one side
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.08), 3.15, 2.9,
            true, p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c.dx - r * 1.05, c.dy - r * 0.9, r * 0.75, r * 0.9),
            Radius.circular(s * 0.04),
          ),
          p,
        );
        break;
      case 3: // Curly — overlapping circles
        for (var i = -2; i <= 2; i++) {
          canvas.drawCircle(
              Offset(c.dx + i * r * 0.42, c.dy - r * 0.72), r * 0.42, p);
        }
        canvas.drawCircle(Offset(c.dx - r * 0.85, c.dy - r * 0.2), r * 0.36, p);
        canvas.drawCircle(Offset(c.dx + r * 0.85, c.dy - r * 0.2), r * 0.36, p);
        break;
      case 4: // Bun
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.06), 3.25, 2.8,
            true, p);
        canvas.drawCircle(Offset(c.dx, c.dy - r * 1.25), r * 0.34, p);
        break;
      case 5: // Long
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.08), 3.15, 2.9,
            true, p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c.dx - r * 1.12, c.dy - r * 0.5, r * 0.42, r * 1.7),
            Radius.circular(s * 0.05),
          ),
          p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c.dx + r * 0.7, c.dy - r * 0.5, r * 0.42, r * 1.7),
            Radius.circular(s * 0.05),
          ),
          p,
        );
        break;
      case 6: // Ponytail
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.06), 3.25, 2.8,
            true, p);
        canvas.drawCircle(Offset(c.dx + r * 1.15, c.dy - r * 0.15), r * 0.3, p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c.dx + r * 0.95, c.dy - r * 0.1, r * 0.36, r * 1.1),
            Radius.circular(s * 0.05),
          ),
          p,
        );
        break;
      case 7: // Wrap / turban
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.14), 3.15, 2.9,
            true, Paint()..color = cloth);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c.dx - r * 1.14, c.dy - r * 0.42, r * 2.28, r * 0.3),
            Radius.circular(s * 0.03),
          ),
          Paint()..color = cloth.withValues(alpha: 0.75),
        );
        break;
      case 8: // Scarf — covers the head and falls to the shoulders
        final scarf = Path()
          ..moveTo(c.dx - r * 1.16, c.dy + r * 1.5)
          ..lineTo(c.dx - r * 1.16, c.dy)
          ..arcToPoint(Offset(c.dx + r * 1.16, c.dy),
              radius: Radius.circular(r * 1.16))
          ..lineTo(c.dx + r * 1.16, c.dy + r * 1.5)
          ..close();
        canvas.drawPath(scarf, Paint()..color = cloth);
        // Face opening
        canvas.drawCircle(
            Offset(c.dx, c.dy + r * 0.06), r * 0.86,
            Paint()..color = ModernAvatar.skinTones[a.skin]);
        break;
    }
  }

  void _paintFace(Canvas canvas, double s, Offset c, double r) {
    final ink = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;

    final eyeY = c.dy - r * 0.05;
    final eyeDx = r * 0.38;

    switch (a.face) {
      case 0: // Calm
        canvas.drawCircle(Offset(c.dx - eyeDx, eyeY), s * 0.022, ink);
        canvas.drawCircle(Offset(c.dx + eyeDx, eyeY), s * 0.022, ink);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy + r * 0.34),
                width: r * 0.7,
                height: r * 0.5),
            0.25,
            2.6,
            false,
            stroke);
        break;
      case 1: // Happy
        for (final dx in [-eyeDx, eyeDx]) {
          canvas.drawArc(
              Rect.fromCenter(
                  center: Offset(c.dx + dx, eyeY),
                  width: r * 0.4,
                  height: r * 0.32),
              3.5,
              2.3,
              false,
              stroke);
        }
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy + r * 0.28),
                width: r * 0.9,
                height: r * 0.7),
            0.2,
            2.7,
            false,
            stroke);
        // Blush
        final blush = Paint()..color = const Color(0x33EF4444);
        canvas.drawCircle(Offset(c.dx - r * 0.72, c.dy + r * 0.3), r * 0.16, blush);
        canvas.drawCircle(Offset(c.dx + r * 0.72, c.dy + r * 0.3), r * 0.16, blush);
        break;
      case 2: // Focused
        canvas.drawLine(Offset(c.dx - eyeDx - r * 0.14, eyeY),
            Offset(c.dx - eyeDx + r * 0.14, eyeY), stroke);
        canvas.drawLine(Offset(c.dx + eyeDx - r * 0.14, eyeY),
            Offset(c.dx + eyeDx + r * 0.14, eyeY), stroke);
        canvas.drawLine(Offset(c.dx - r * 0.22, c.dy + r * 0.42),
            Offset(c.dx + r * 0.22, c.dy + r * 0.42), stroke);
        break;
      case 3: // Meditating — closed eyes
        for (final dx in [-eyeDx, eyeDx]) {
          canvas.drawArc(
              Rect.fromCenter(
                  center: Offset(c.dx + dx, eyeY),
                  width: r * 0.42,
                  height: r * 0.3),
              0.2,
              2.7,
              false,
              stroke);
        }
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy + r * 0.34),
                width: r * 0.6,
                height: r * 0.4),
            0.3,
            2.5,
            false,
            stroke);
        break;
    }
  }

  void _paintAccessory(
      Canvas canvas, double s, Offset c, double r, Color hair) {
    switch (a.accessory) {
      case 1: // Glasses
        final g = Paint()
          ..color = const Color(0xFF111827)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02;
        final eyeY = c.dy - r * 0.05;
        canvas.drawCircle(Offset(c.dx - r * 0.38, eyeY), r * 0.28, g);
        canvas.drawCircle(Offset(c.dx + r * 0.38, eyeY), r * 0.28, g);
        canvas.drawLine(Offset(c.dx - r * 0.1, eyeY), Offset(c.dx + r * 0.1, eyeY), g);
        break;
      case 2: // Headphones
        final band = Paint()
          ..color = const Color(0xFF111827)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.035;
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 1.16), 3.34, 2.6, false, band);
        final pad = Paint()..color = const Color(0xFF111827);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx - r * 1.16, c.dy + r * 0.05),
                width: s * 0.07,
                height: s * 0.12),
            Radius.circular(s * 0.03),
          ),
          pad,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx + r * 1.16, c.dy + r * 0.05),
                width: s * 0.07,
                height: s * 0.12),
            Radius.circular(s * 0.03),
          ),
          pad,
        );
        break;
      case 3: // Cap
        final capColor = ModernAvatar.clothesColors[a.clothes];
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.1), 3.2, 2.85,
            true, Paint()..color = capColor);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c.dx - r * 0.2, c.dy - r * 0.95, r * 1.5, r * 0.26),
            Radius.circular(s * 0.03),
          ),
          Paint()..color = capColor.withValues(alpha: 0.85),
        );
        break;
      case 4: // Earrings
        final e = Paint()..color = const Color(0xFFFBBF24);
        canvas.drawCircle(
            Offset(c.dx - r * 1.0, c.dy + r * 0.28), s * 0.022, e);
        canvas.drawCircle(
            Offset(c.dx + r * 1.0, c.dy + r * 0.28), s * 0.022, e);
        break;
      case 5: // Bindi
        canvas.drawCircle(Offset(c.dx, c.dy - r * 0.5), s * 0.02,
            Paint()..color = const Color(0xFFDC2626));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) => old.a.id != a.id;
}
