import 'package:flutter/material.dart';

class AppTheme {
  // Define your colors
  static const Color primaryGreen = Color(0xFF008300);
  static const Color darkGreen = Color(0xFF006A00);
  static const Color lightGreen = Color(0xFF229022);
  static const Color primaryBlue = Color(0xFF003299);
  static const Color darkBlue = Color(0xFF00018D);
  static const Color veryDarkBlue = Color(0xFF05006D);

  // Centralized ThemeData
  static ThemeData get themeData {
    return ThemeData(
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(
        secondary: primaryBlue,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkGreen,
        ),
        bodyMedium: TextStyle(fontSize: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        filled: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}