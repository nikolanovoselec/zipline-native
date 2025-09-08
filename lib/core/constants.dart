import 'package:flutter/material.dart';

class AppConstants {
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 150);
  static const Duration defaultAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Border radius
  static const double smallRadius = 8.0;
  static const double defaultRadius = 12.0;
  static const double largeRadius = 18.0;
  static const double extraLargeRadius = 24.0;

  // Padding and margins
  static const double smallPadding = 8.0;
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 32.0;

  // Touch targets (minimum for accessibility)
  static const double minTouchTarget = 48.0;

  // Icon sizes
  static const double smallIcon = 16.0;
  static const double defaultIcon = 24.0;
  static const double largeIcon = 32.0;
  static const double extraLargeIcon = 48.0;

  // Font sizes
  static const double smallText = 12.0;
  static const double defaultText = 14.0;
  static const double mediumText = 16.0;
  static const double largeText = 18.0;
  static const double extraLargeText = 24.0;

  // Glassmorphic opacity
  static const double glassmorphicOpacity = 0.041;
  static const double glassmorphicBorderOpacity = 0.09;

  // Colors
  static const Color primaryBackground = Color(0xFF0D1B2A);
  static const Color secondaryBackground = Color(0xFF1B263B);
  static const Color surfaceColor = Color(0xFF2C3E50);
  static const Color accentColor = Color(0xFF00BFA5);
  static const Color errorColor = Color(0xFFCF6679);
  static const Color successColor = Color(0xFF00C853);
  static const Color warningColor = Color(0xFFFFA000);

  // Breakpoints for responsive design
  static const double phoneBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
}

class AppTheme {
  static ThemeData darkTheme = ThemeData.dark().copyWith(
    colorScheme: ColorScheme.dark(
      primary: AppConstants.accentColor,
      secondary: AppConstants.accentColor,
      surface: AppConstants.surfaceColor,
      error: AppConstants.errorColor,
    ),
    scaffoldBackgroundColor: AppConstants.primaryBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(88, AppConstants.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
          vertical: AppConstants.smallPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        borderSide: BorderSide(
          color: AppConstants.accentColor,
        ),
      ),
    ),
  );

  static ThemeData lightTheme = ThemeData.light().copyWith(
    colorScheme: ColorScheme.light(
      primary: AppConstants.accentColor,
      secondary: AppConstants.accentColor,
      surface: Colors.grey[100]!,
      error: AppConstants.errorColor,
    ),
    scaffoldBackgroundColor: Colors.grey[50],
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(88, AppConstants.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
          vertical: AppConstants.smallPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        borderSide: BorderSide(
          color: Colors.grey[300]!,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        borderSide: BorderSide(
          color: Colors.grey[300]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        borderSide: BorderSide(
          color: AppConstants.accentColor,
        ),
      ),
    ),
  );
}
