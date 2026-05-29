import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF2B70A4); // Precise Figma Primary Blue
  static const Color primaryDark = Color(0xFF1E527D);
  static const Color primaryLight = Color(0xFFE6F0F9);
  static const Color accent = Color(0xFF4A90D9);
  static const Color background = Color(0xFFF8FAFC); // Very Light Blue-Gray
  static const Color white = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Dark Navy Header
  static const Color textSecondary = Color(0xFF64748B); // Slate Gray Body
  static const Color textHint = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0); // Subtle Slate Border
  static const Color success = Color(0xFF4CAF50); // Figma Success
  static const Color warning = Color(0xFFF5A623); // Figma Warning
  static const Color error = Color(0xFFD32F2F); // Figma Error
  static const Color cardBg = Colors.white;
  static const Color highRisk = Color(0xFFD32F2F);
  static const Color mediumRisk = Color(0xFFF5A623);
  static const Color lowRisk = Color(0xFF4CAF50);
}

class AppTheme {
  static ThemeData get theme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : AppColors.white;
    final scaffold = isDark ? const Color(0xFF0F172A) : AppColors.background;
    final onSurface = isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimary;
    final border = isDark ? const Color(0xFF334155) : AppColors.border;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: scaffold,
      dividerColor: border,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: surface,
        onSurface: onSurface,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ).apply(bodyColor: onSurface, displayColor: onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: onSurface,
        ),
      ),
      cardColor: surface,
      listTileTheme: ListTileThemeData(
        iconColor: onSurface,
        textColor: onSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }
}
