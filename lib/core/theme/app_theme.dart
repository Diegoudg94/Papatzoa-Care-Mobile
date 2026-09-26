import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF35695B);
  static const Color primarySoft = Color(0xFF5B8B7C);
  static const Color background = Color(0xFFF6F7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color warmAccent = Color(0xFFF4D6B8);
  static const Color textPrimary = Color(0xFF1F2933);
  static const Color textSecondary = Color(0xFF65716C);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ),
    );
  }
}
