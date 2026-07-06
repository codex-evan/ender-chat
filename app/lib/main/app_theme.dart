/// App theme definitions - modern, privacy-focused aesthetic

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();
  
  // Color palette - dark, privacy-focused
  static const _primaryColor = Color(0xFF6C5CE7);
  static const _secondaryColor = Color(0xFF00CEC9);
  static const _accentColor = Color(0xFFFD79A8);
  
  // Dark theme colors
  static const _darkBg = Color(0xFF0D0D0D);
  static const _darkSurface = Color(0xFF1A1A1A);
  static const _darkCard = Color(0xFF252525);
  static const _darkBorder = Color(0xFF333333);
  
  // Light theme colors
  static const _lightBg = Color(0xFFF8F9FA);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightCard = Color(0xFFF0F0F0);
  static const _lightBorder = Color(0xFFE0E0E0);

  // Shared typography
  static const _textStyle = TextStyle(
    fontFamily: 'SF Pro',
    fontWeight: FontWeight.w400,
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkBg,
    colorScheme: const ColorScheme.dark(
      primary: _primaryColor,
      secondary: _secondaryColor,
      surface: _darkSurface,
      onSurface: Colors.white,
      primaryContainer: _darkCard,
      onPrimaryContainer: Colors.white,
    ),
    textTheme: TextTheme(
      displayLarge: _textStyle.copyWith(fontSize: 32, fontWeight: FontWeight.bold),
      headlineLarge: _textStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
      headlineMedium: _textStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: _textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: _textStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: _textStyle.copyWith(fontSize: 16),
      bodyMedium: _textStyle.copyWith(fontSize: 14),
      bodySmall: _textStyle.copyWith(fontSize: 12),
    ),
    cardTheme: CardTheme(
      color: _darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    dividerTheme: const DividerThemeData(color: _darkBorder, thickness: 1),
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBg,
    colorScheme: const ColorScheme.light(
      primary: _primaryColor,
      secondary: _secondaryColor,
      surface: _lightSurface,
      onSurface: Colors.black87,
      primaryContainer: _lightCard,
      onPrimaryContainer: Colors.black87,
    ),
    textTheme: TextTheme(
      displayLarge: _textStyle.copyWith(fontSize: 32, fontWeight: FontWeight.bold),
      headlineLarge: _textStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
      headlineMedium: _textStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: _textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: _textStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: _textStyle.copyWith(fontSize: 16),
      bodyMedium: _textStyle.copyWith(fontSize: 14),
      bodySmall: _textStyle.copyWith(fontSize: 12),
    ),
    cardTheme: CardTheme(
      color: _lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      border: Border.all(color: _lightBorder),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.black87),
    dividerTheme: DividerThemeData(color: _lightBorder, thickness: 1),
  );
}
