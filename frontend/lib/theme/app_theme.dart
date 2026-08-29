import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Modern Heritage Color Palette
  static const Color primary = Color(0xFF012D1D); // Royal India Green
  static const Color primaryContainer = Color(0xFF1B4332);
  static const Color secondary = Color(0xFF8E4E14); // Saffron Gold
  static const Color secondaryContainer = Color(0xFFFFAB69);
  
  static const Color background = Color(0xFFF9FAF6); // Eggshell
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFDADAD7);
  
  static const Color error = Color(0xFFBA1A1A);
  
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.white;
  static const Color onBackground = Color(0xFF1A1C1A); // Coal Grey
  static const Color onSurface = Color(0xFF1A1C1A);

  static ThemeData get lightTheme {
    final textTheme = TextTheme(
      displayLarge: GoogleFonts.montserrat(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: onBackground,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.montserrat(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onBackground,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        color: onBackground,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: onBackground,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: const Color(0xFF717973),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: primaryContainer,
        secondary: secondary,
        secondaryContainer: secondaryContainer,
        surface: surface,
        error: error,
        onPrimary: onPrimary,
        onSecondary: onSecondary,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Color(0x1A000000), // Colors.black.withOpacity(0.1) as const
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFFE9ECEF), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondary,
          foregroundColor: onSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC1C8C2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC1C8C2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        filled: true,
        fillColor: surface,
      ),
    );
  }
}
