import 'package:flutter/material.dart';

class AppTheme {
  // Primary color that works for both themes
  static const Color primaryColor = Color(0xFF116DE6);
  
  // Light theme colors
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightCardBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCardBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  
  // Shadow styles
  static List<BoxShadow> get lightShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 3,
      offset: const Offset(0, 1),
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> get darkShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 3,
      offset: const Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  // Helper method to get appropriate shadow based on brightness
  static List<BoxShadow> getShadow(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkShadow : lightShadow;
  }
  
  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBackground,
    
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: primaryColor,
      surface: lightCardBackground,
      error: Colors.red,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.black87,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
    ),
    
    cardTheme: CardThemeData(
      color: lightCardBackground,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightCardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
    
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey[200]!,
      selectedColor: primaryColor.withOpacity(0.2),
      labelStyle: const TextStyle(color: Colors.black87),
    ),
    
    dividerTheme: DividerThemeData(
      color: Colors.grey[200],
      thickness: 1,
    ),
  );
  
  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: primaryColor,
      surface: darkCardBackground,
      error: Colors.red,
      onSurface: Colors.white,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    
    cardTheme: CardThemeData(
      color: darkCardBackground,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
    ),
    
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey[800]!,
      selectedColor: primaryColor.withOpacity(0.3),
      labelStyle: const TextStyle(color: Colors.white),
    ),
    
    dividerTheme: DividerThemeData(
      color: Colors.grey[800],
      thickness: 1,
    ),
    
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white60),
    ),
  );
}