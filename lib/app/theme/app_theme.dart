import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.ocean,
        brightness: Brightness.light,
        primary: AppColors.ocean,
        secondary: AppColors.mint,
        surface: Colors.white,
      ),
      useMaterial3: true,
    );

    final textTheme = GoogleFonts.spaceGroteskTextTheme(base.textTheme)
        .copyWith(
          bodyMedium: GoogleFonts.dmSans(textStyle: base.textTheme.bodyMedium),
          bodyLarge: GoogleFonts.dmSans(textStyle: base.textTheme.bodyLarge),
          bodySmall: GoogleFonts.dmSans(textStyle: base.textTheme.bodySmall),
          labelLarge: GoogleFonts.dmSans(textStyle: base.textTheme.labelLarge),
          labelMedium: GoogleFonts.dmSans(
            textStyle: base.textTheme.labelMedium,
          ),
          titleMedium: GoogleFonts.dmSans(
            textStyle: base.textTheme.titleMedium,
          ),
          titleSmall: GoogleFonts.dmSans(textStyle: base.textTheme.titleSmall),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.sand,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.cloud,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.mint,
        brightness: Brightness.dark,
        primary: AppColors.mint,
        secondary: AppColors.ocean,
        surface: const Color(0xFF10202C),
      ),
      useMaterial3: true,
    );

    final textTheme = GoogleFonts.spaceGroteskTextTheme(base.textTheme)
        .copyWith(
          bodyMedium: GoogleFonts.dmSans(textStyle: base.textTheme.bodyMedium),
          bodyLarge: GoogleFonts.dmSans(textStyle: base.textTheme.bodyLarge),
          bodySmall: GoogleFonts.dmSans(textStyle: base.textTheme.bodySmall),
          labelLarge: GoogleFonts.dmSans(textStyle: base.textTheme.labelLarge),
          labelMedium: GoogleFonts.dmSans(
            textStyle: base.textTheme.labelMedium,
          ),
          titleMedium: GoogleFonts.dmSans(
            textStyle: base.textTheme.titleMedium,
          ),
          titleSmall: GoogleFonts.dmSans(textStyle: base.textTheme.titleSmall),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.night,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF132636),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF10202C),
        indicatorColor: const Color(0xFF1F3C4E),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
