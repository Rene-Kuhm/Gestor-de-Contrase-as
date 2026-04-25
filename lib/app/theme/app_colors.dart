import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand — sophisticated violet
  static const Color brand = Color(0xFF7C3AED);
  static const Color brandLight = Color(0xFFA78BFA);
  static const Color brandSubtle = Color(0xFFEDE9FE);
  static const Color brandSubtleDark = Color(0xFF2E1065);

  // Surfaces — light
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF4F4F5);

  // Surfaces — dark
  static const Color backgroundDark = Color(0xFF09090B);
  static const Color surfaceDark = Color(0xFF18181B);
  static const Color surfaceMutedDark = Color(0xFF27272A);

  // Borders
  static const Color border = Color(0xFFE4E4E7);
  static const Color borderDark = Color(0xFF27272A);

  // Text
  static const Color textPrimary = Color(0xFF09090B);
  static const Color textPrimaryDark = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFF71717A);
  static const Color textSecondaryDark = Color(0xFFA1A1AA);

  // Status — restrained, only for status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Legacy aliases — preserve existing API surface
  static const Color ink = textPrimary;
  static const Color slate = Color(0xFF52525B);
  static const Color ocean = brand;
  static const Color mint = success;
  static const Color sand = background;
  static const Color cloud = surfaceMuted;
  static const Color night = backgroundDark;
  static const Color steel = textSecondary;
}
