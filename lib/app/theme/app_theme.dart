import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF2563EB); // Modern Royal Blue
  static const Color primaryAccent = Color(0xFF004AC6); // Deep Tech Blue
  static const Color secondary = Color(0xFF006C49); // Emerald Green
  static const Color secondaryContainer = Color(0xFF6CF8BB); // Soft Emerald
  static const Color tertiary = Color(0xFF3E3FCC); // Modern Indigo
  static const Color background = Color(0xFFF1F5F9); // Crisp Slate Canvas for distinct card separation
  static const Color surface = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFF2F3FF);
  static const Color surfaceContainerHigh = Color(0xFFE2E7FF);
  static const Color cardBorder = Color(0xFFE2E8F0);
  
  static const Color textPrimary = Color(0xFF131B2E);
  static const Color textSecondary = Color(0xFF434655);
  static const Color textMuted = Color(0xFF64748B);
  
  static const Color success = Color(0xFF006C49);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFBA1A1A);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
