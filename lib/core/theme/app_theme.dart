import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF7C3AED); // Deep Purple
  static const Color primaryLight = Color(0xFF9F67FA);
  static const Color primaryDark = Color(0xFF5B21B6);
  static const Color accent = Color(0xFFF59E0B); // Gold/Amber
  static const Color accentLight = Color(0xFFFBBF24);

  // Background Colors
  static const Color bgDark = Color(0xFF0D0D1A);
  static const Color bgCard = Color(0xFF1A1A2E);
  static const Color bgCardLight = Color(0xFF16213E);
  static const Color bgSurface = Color(0xFF0F3460);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8F8FF);
  static const Color textSecondary = Color(0xFFB0B0CC);
  static const Color textMuted = Color(0xFF6B6B8A);

  // Mood Colors
  static const Color moodVerySad = Color(0xFF6366F1);
  static const Color moodSad = Color(0xFF8B5CF6);
  static const Color moodNeutral = Color(0xFFF59E0B);
  static const Color moodHappy = Color(0xFF10B981);
  static const Color moodVeryHappy = Color(0xFF06D6A0);

  // ─────────────────────── design tokens ───────────────────────
  //
  // Added so spacing, radii and borders stop being magic numbers repeated
  // across screens. The colour and gradient names above are unchanged — the
  // rest of the app still references them directly.

  /// Hairline that separates a card from the backdrop. Was written as the
  /// literal 0xFF2D2D4E in ~40 places.
  static const Color border = Color(0xFF2D2D4E);
  static const Color borderSoft = Color(0xFF23233F);

  /// Warm ink used behind sacred motifs — a hint of gold in the violet keeps
  /// the dark theme from reading as cold blue-grey.
  static const Color sacredGlow = Color(0xFF3B2A6B);
  static const Color sacredInk = Color(0xFF14101F);

  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFB91C1C);

  // 4-point spacing scale.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;

  // Corner radii.
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusPill = 999;

  /// Soft ambient lift for raised surfaces. Dark themes need shadow that reads
  /// as depth rather than dirt, so it is deep and very diffuse.
  static List<BoxShadow> get shadowSoft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> glow(Color color, {double strength = 0.35}) => [
        BoxShadow(
          color: color.withValues(alpha: strength),
          blurRadius: 28,
          spreadRadius: 2,
        ),
      ];

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E), Color(0xFF0F3460)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Outfit',
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: bgCard,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: bgDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2D2D4E), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D2D4E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D2D4E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontFamily: 'Outfit'),
        hintStyle: const TextStyle(color: textMuted, fontFamily: 'Outfit'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgCard,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Outfit', color: textPrimary, fontSize: 34, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontFamily: 'Outfit', color: textPrimary, fontSize: 30, fontWeight: FontWeight.w600),
        headlineLarge: TextStyle(fontFamily: 'Outfit', color: textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontFamily: 'Outfit', color: textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontFamily: 'Outfit', color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontFamily: 'Outfit', color: textPrimary, fontSize: 18, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontFamily: 'Outfit', color: textPrimary, fontSize: 18),
        bodyMedium: TextStyle(fontFamily: 'Outfit', color: textSecondary, fontSize: 16),
        bodySmall: TextStyle(fontFamily: 'Outfit', color: textMuted, fontSize: 14),
      ),
    );
  }
}
