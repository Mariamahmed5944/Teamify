import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persists and exposes light / dark [ThemeMode] for [MaterialApp].
class ThemeController extends ChangeNotifier {
  static const _boxName = 'app_settings';
  static const _darkKey = 'dark_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    try {
      final box = await Hive.openBox(_boxName);
      final dark = box.get(_darkKey) == true;
      _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {
      // Keep default light theme if storage is unavailable.
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_darkKey, enabled);
    } catch (_) {}
  }

  Future<void> toggle() => setDarkMode(!isDark);
}
