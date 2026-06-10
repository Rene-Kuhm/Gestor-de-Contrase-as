import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Vaulta theme.
///
/// The product is dark-first. The light theme exists for users who
/// explicitly opt in, but every screen is verified against the
/// dark theme first. Color tokens are pulled from [AppColors]; this
/// file is the only place that maps them to [ThemeData] /
/// [ColorScheme] so a token swap is a one-file change.
abstract final class AppTheme {
  /// Dark theme. The default and the one the visual redesign was
  /// drawn for.
  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.crimson,
      onPrimary: AppColors.paperDark,
      primaryContainer: AppColors.crimsonDeep,
      onPrimaryContainer: AppColors.paperDark,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      secondaryContainer: Color(0x33F2C70F),
      onSecondaryContainer: AppColors.paperDark,
      tertiary: AppColors.success,
      onTertiary: AppColors.ink,
      tertiaryContainer: Color(0x334FB58E),
      onTertiaryContainer: AppColors.paperDark,
      error: AppColors.danger,
      onError: AppColors.paperDark,
      errorContainer: Color(0x33C0392B),
      onErrorContainer: AppColors.paperDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
      surfaceContainerLowest: AppColors.backgroundDark,
      surfaceContainerLow: AppColors.surfaceDark,
      surfaceContainer: AppColors.surfaceDarkHigh,
      surfaceContainerHigh: AppColors.surfaceDarkHigh,
      surfaceContainerHighest: AppColors.surfaceDarkHighest,
      outline: AppColors.borderDarkStrong,
      outlineVariant: AppColors.borderDark,
      inverseSurface: AppColors.paperDark,
      onInverseSurface: AppColors.ink,
      inversePrimary: AppColors.crimsonDeep,
      scrim: Color(0xCC000000),
      shadow: Color(0xCC000000),
      surfaceTint: AppColors.crimson,
    );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      canvasColor: AppColors.backgroundDark,
      fontFamily: GoogleFonts.inter().fontFamily,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      iconTheme: const IconThemeData(color: AppColors.textPrimaryDark, size: 22),
      primaryIconTheme: const IconThemeData(color: AppColors.paperDark),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _textTheme(base.textTheme).titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.backgroundDark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceDarkHigh,
        selectedColor: AppColors.crimson.withValues(alpha: 0.18),
        disabledColor: AppColors.surfaceDarkHigh.withValues(alpha: 0.4),
        side: const BorderSide(color: AppColors.borderDark),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.crimsonBright,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.crimson.withValues(alpha: 0.18),
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
            color: selected ? AppColors.crimsonBright : AppColors.textTertiaryDark,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.crimsonBright : AppColors.textSecondaryDark,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDarkHigh.withValues(alpha: 0.6),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textTertiaryDark,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondaryDark,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.crimsonBright,
        ),
        helperStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textTertiaryDark,
        ),
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.danger,
        ),
        prefixIconColor: AppColors.textTertiaryDark,
        suffixIconColor: AppColors.textTertiaryDark,
        border: _inputBorder(AppColors.borderDark),
        enabledBorder: _inputBorder(AppColors.borderDark),
        focusedBorder: _inputBorder(AppColors.crimson, width: 1.5),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.crimson,
          foregroundColor: AppColors.paperDark,
          disabledBackgroundColor: AppColors.surfaceDarkHigh,
          disabledForegroundColor: AppColors.textTertiaryDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          minimumSize: const Size(0, 52),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          side: const BorderSide(color: AppColors.borderDarkStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          minimumSize: const Size(0, 52),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.crimsonBright,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.crimson,
        foregroundColor: AppColors.paperDark,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLg)),
        ),
        extendedTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDarkHighest,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.crimsonBright,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryDark,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondaryDark,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
          side: BorderSide(color: AppColors.borderDark),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.crimson,
        inactiveTrackColor: AppColors.surfaceDarkHighest,
        thumbColor: AppColors.paperDark,
        overlayColor: AppColors.crimson.withValues(alpha: 0.15),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.paperDark;
          }
          return AppColors.textTertiaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.crimson;
          }
          return AppColors.surfaceDarkHighest;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.crimson,
        circularTrackColor: AppColors.surfaceDarkHighest,
        linearTrackColor: AppColors.surfaceDarkHighest,
      ),
    );
  }

  /// Light theme. The visual language is the same as dark, just
  /// inverted surfaces. We deliberately keep crimson as the only
  /// saturated color so the brand stays consistent.
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.crimson,
      onPrimary: AppColors.paperDark,
      primaryContainer: AppColors.crimsonDeep,
      onPrimaryContainer: AppColors.paperDark,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      secondaryContainer: Color(0x33F2C70F),
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.success,
      onTertiary: AppColors.paperDark,
      tertiaryContainer: Color(0x334FB58E),
      onTertiaryContainer: AppColors.ink,
      error: AppColors.danger,
      onError: AppColors.paperDark,
      errorContainer: Color(0x22C0392B),
      onErrorContainer: AppColors.crimsonDeep,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,
      onSurfaceVariant: AppColors.textSecondaryLight,
      surfaceContainerLowest: AppColors.backgroundLight,
      surfaceContainerLow: AppColors.surfaceLight,
      surfaceContainer: AppColors.surfaceLightHigh,
      surfaceContainerHigh: AppColors.surfaceLightHigh,
      surfaceContainerHighest: AppColors.surfaceLightHighest,
      outline: AppColors.borderLightStrong,
      outlineVariant: AppColors.borderLight,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.paperDark,
      inversePrimary: AppColors.crimsonBright,
      scrim: Color(0xCC000000),
      shadow: Color(0x33000000),
      surfaceTint: AppColors.crimson,
    );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      canvasColor: AppColors.backgroundLight,
      fontFamily: GoogleFonts.inter().fontFamily,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      iconTheme: const IconThemeData(color: AppColors.textPrimaryLight, size: 22),
      primaryIconTheme: const IconThemeData(color: AppColors.paperDark),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _textTheme(base.textTheme).titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.backgroundLight,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceLightHigh,
        selectedColor: AppColors.crimson.withValues(alpha: 0.14),
        side: const BorderSide(color: AppColors.borderLight),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.crimson,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.crimson.withValues(alpha: 0.16),
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
            color: selected ? AppColors.crimson : AppColors.textTertiaryLight,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.crimson : AppColors.textSecondaryLight,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textTertiaryLight,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondaryLight,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.crimson,
        ),
        helperStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textTertiaryLight,
        ),
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.danger,
        ),
        border: _inputBorder(AppColors.borderLight),
        enabledBorder: _inputBorder(AppColors.borderLight),
        focusedBorder: _inputBorder(AppColors.crimson, width: 1.5),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.crimson,
          foregroundColor: AppColors.paperDark,
          disabledBackgroundColor: AppColors.surfaceLightHighest,
          disabledForegroundColor: AppColors.textTertiaryLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          minimumSize: const Size(0, 52),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryLight,
          side: const BorderSide(color: AppColors.borderLightStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          minimumSize: const Size(0, 52),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.crimson,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.crimson,
        foregroundColor: AppColors.paperDark,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLg)),
        ),
        extendedTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.paperDark,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.crimsonBright,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryLight,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondaryLight,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
          side: BorderSide(color: AppColors.borderLight),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.crimson,
        inactiveTrackColor: AppColors.surfaceLightHighest,
        thumbColor: AppColors.crimson,
        overlayColor: AppColors.crimson.withValues(alpha: 0.15),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.paperDark;
          }
          return AppColors.textTertiaryLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.crimson;
          }
          return AppColors.surfaceLightHighest;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.crimson,
        circularTrackColor: AppColors.surfaceLightHighest,
        linearTrackColor: AppColors.surfaceLightHighest,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    final primaryDark = AppColors.textPrimaryDark;
    final secondaryDark = AppColors.textSecondaryDark;
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        color: primaryDark,
        height: 1.05,
        letterSpacing: -1.0,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: primaryDark,
        height: 1.1,
        letterSpacing: -0.6,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: primaryDark,
        height: 1.15,
        letterSpacing: -0.4,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primaryDark,
        height: 1.2,
        letterSpacing: -0.3,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primaryDark,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primaryDark,
        height: 1.3,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primaryDark,
        height: 1.35,
        letterSpacing: -0.1,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryDark,
        height: 1.4,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryDark,
        height: 1.4,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: primaryDark,
        height: 1.55,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryDark,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondaryDark,
        height: 1.5,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: primaryDark,
        letterSpacing: 0.2,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondaryDark,
        letterSpacing: 0.3,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: secondaryDark,
        letterSpacing: 0.4,
      ),
    );
  }
}
