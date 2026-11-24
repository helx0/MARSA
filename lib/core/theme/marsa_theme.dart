import 'package:flutter/material.dart';

class MarsaColors {
  // A palette inspired by the Arabian Sea and Aden's coast
  static const navy = Color(0xFF073B4C);      // Deep sea navy
  static const teal = Color(0xFF0E7C86);      // Professional teal
  static const turquoise = Color(0xFF22B8B0); // Light sea foam
  static const seafoam = Color(0xFFDFF3EF);   // Background tint
  static const sand = Color(0xFFF4EBDD);      // Beach sand
  static const coral = Color(0xFFF0785A);     // Sunset coral
  static const slate = Color(0xFF20343B);     // Text/Heading color
  static const muted = Color(0xFF6B7C82);     // Secondary text
}

ThemeData marsaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MarsaColors.teal,
    primary: MarsaColors.navy,
    secondary: MarsaColors.teal,
    surface: Colors.white,
    error: MarsaColors.coral,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF9FDFD),
    
    // Bold Adeni identity
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: MarsaColors.navy,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: MarsaColors.navy,
      ),
    ),
    
    // Professional forms
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2EAEC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2EAEC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MarsaColors.teal, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    ),
    
    // Modern Cards
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2EAEC)),
      ),
    ),
    
    // "Strong" Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MarsaColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(54, 54),
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MarsaColors.teal,
        side: const BorderSide(color: MarsaColors.teal),
        minimumSize: const Size(54, 54),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: MarsaColors.navy),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, color: MarsaColors.navy),
      bodyMedium: TextStyle(color: MarsaColors.slate),
    ),
  );
}
