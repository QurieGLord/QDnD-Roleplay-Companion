import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFFFFB3D9), // Monokai pink
      onPrimary: Color(0xFF2D2A2E),
      secondary: Color(0xFFA9DC76), // Monokai green
      onSecondary: Color(0xFF2D2A2E),
      surface: Color(0xFFFCFCFC),
      onSurface: Color(0xFF2D2A2E),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFFFFB3D9),
      onPrimary: Color(0xFF2D2A2E),
      secondary: Color(0xFFA9DC76),
      onSecondary: Color(0xFF2D2A2E),
      surface: Color(0xFF2D2A2E),
      onSurface: Color(0xFFFCFCFC),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
