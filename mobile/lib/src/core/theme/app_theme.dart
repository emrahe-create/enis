import 'package:flutter/material.dart';

import '../brand/enis_brand.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: EnisColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: EnisColors.primaryBlue,
        brightness: Brightness.light,
      ).copyWith(
        primary: EnisColors.primaryBlue,
        secondary: EnisColors.lavender,
        tertiary: EnisColors.softPurple,
        surface: EnisColors.white,
        onSurface: EnisColors.deepNavy,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: EnisColors.background,
        foregroundColor: EnisColors.deepNavy,
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: EnisColors.white,
        indicatorColor: EnisColors.primaryBlue.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? EnisColors.primaryBlue
                : EnisColors.deepNavy.withValues(alpha: 0.62),
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EnisColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: EnisColors.deepNavy.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: EnisColors.deepNavy.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: EnisColors.primaryBlue, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          color: EnisColors.deepNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          color: EnisColors.deepNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: EnisColors.deepNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: EnisColors.deepNavy,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: EnisColors.deepNavy,
          height: 1.42,
          letterSpacing: 0,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: EnisColors.deepNavy.withValues(alpha: 0.76),
          height: 1.38,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
