import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  
  ThemeProvider() {
    _loadTheme();
  }
  
  // Toggle between light and dark mode
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    _saveTheme();
    notifyListeners();
  }
  
  // Set specific theme mode
  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    _saveTheme();
    notifyListeners();
  }
  
  // Load saved theme preference
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString('theme') ?? 'system';
      _themeMode = _getThemeModeFromString(theme);
      notifyListeners();
    } catch (e) {
      print('Error loading theme: $e');
    }
  }
  
  // Save theme preference
  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme', _themeMode.toString().split('.').last);
    } catch (e) {
      print('Error saving theme: $e');
    }
  }
  
  // Convert string to ThemeMode
  ThemeMode _getThemeModeFromString(String theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
  
  // Get theme mode name for display
  String get themeModeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}