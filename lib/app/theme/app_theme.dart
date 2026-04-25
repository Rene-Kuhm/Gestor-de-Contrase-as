import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
        primary: AppColors.brand,
        secondary: AppColors.brandLight,
        surface: AppColors.surface,
        error: AppColors.danger,
        outline: AppColors.border,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme(
        base.textTheme,
        AppColors.textPrimary,
        AppColors.textSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.brandSubtle,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brandSubtle,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(size: 22, color: AppColors.textPrimary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.brand, width: 1.5),
        errorBorder: _inputBorder(AppColors.danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandLight,
        brightness: Brightness.dark,
        primary: AppColors.brandLight,
        secondary: AppColors.brand,
        surface: AppColors.surfaceDark,
        error: AppColors.danger,
        outline: AppColors.borderDark,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: _textTheme(
        base.textTheme,
        AppColors.textPrimaryDark,
        AppColors.textSecondaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceMutedDark,
        selectedColor: AppColors.brandSubtleDark,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimaryDark,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.brandSubtleDark,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(size: 22, color: AppColors.textPrimaryDark),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondaryDark,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondaryDark,
        ),
        border: _inputBorder(AppColors.borderDark),
        enabledBorder: _inputBorder(AppColors.borderDark),
        focusedBorder: _inputBorder(AppColors.brandLight, width: 1.5),
        errorBorder: _inputBorder(AppColors.danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandLight,
          foregroundColor: AppColors.backgroundDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          side: const BorderSide(color: AppColors.borderDark),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandLight,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandLight,
        foregroundColor: AppColors.backgroundDark,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceMutedDark,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(
    TextTheme base,
    Color primary,
    Color secondary,
  ) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.1,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.15,
        letterSpacing: -0.4,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.2,
        letterSpacing: -0.3,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.3,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.35,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.4,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.4,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.45,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondary,
        letterSpacing: 0.2,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondary,
        letterSpacing: 0.3,
      ),
    );
  }
}
