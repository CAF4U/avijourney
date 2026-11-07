import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E5AA8),
            brightness: Brightness.light,
            secondary: const Color(0xFF6D1F7B)),
        scaffoldBackgroundColor: const Color(0xFFF4F7FA),
        useMaterial3: true,
      );

  static ThemeData dark() {
    const background = Color(0xFF050906);
    const surface = Color(0xFF09150E);
    const primary = Color(0xFF69E58B);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: surface,
        secondary: Color(0xFFFFD166),
        error: Color(0xFFFF6B6B),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF07110B),
        foregroundColor: Color(0xFFE6F6EA),
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF0B1B11),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF1D3B27)),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerColor: const Color(0xFF24472F),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFFD8E8DC)),
        bodySmall: TextStyle(color: Color(0xFF94AA9A)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: Color(0xFF173C25),
      ),
      useMaterial3: true,
    );
  }
}
