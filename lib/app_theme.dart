import 'package:flutter/material.dart';

class AppTheme {
  // Define your colors
  static const Color primaryGreen = Color(0xFF008300);
  static const Color darkGreen = Color(0xFF006A00);
  static const Color lightGreen = Color(0xFF229022);
  static const Color primaryBlue = Color(0xFF003299);
  static const Color darkBlue = Color(0xFF00018D);
  static const Color veryDarkBlue = Color(0xFF05006D);

  static ThemeData get themeData {
    return ThemeData(
      // Switch to primaryBlue for a modern “electric” vibe
      primaryColor: primaryBlue,

      // Use a custom ColorScheme so that you can still keep green as an accent
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: _createMaterialColor(primaryBlue),
        brightness: Brightness.light,
      ).copyWith(
        secondary: primaryGreen,
      ),

      // Set a light background color for the entire app
      scaffoldBackgroundColor: Colors.grey[100],

      // Customize the AppBar to match your brand color
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        elevation: 4,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold
        ),
      ),

      // Drawer theme (for the background, scrim, etc.)
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
      ),

      // Customize your text styles
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkBlue, // or keep darkGreen if you prefer
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),

      // Style input fields
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        filled: true,
        fillColor: Colors.white, // White fill for contrast
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightGreen, // or primaryBlue
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightGreen,
        foregroundColor: Colors.white,
      ),

      // DataTable theme for consistent heading style
      dataTableTheme: DataTableThemeData(
        headingRowColor: MaterialStateProperty.all(primaryGreen),
        headingTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        dataRowHeight: 56,
        headingRowHeight: 56,
      ),
    );
  }

  /// Helper method to create a MaterialColor from a custom color
  static MaterialColor _createMaterialColor(Color color) {
    List<double> strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
}