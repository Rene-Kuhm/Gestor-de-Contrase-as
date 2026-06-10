import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  // Base grid in 4-px increments. We don't expose 1 / 2 / 3 because
  // every spacing decision in the redesign snaps to the 4-px grid.
  static const double unit = 4;

  static const double xxs = 4; // 1u
  static const double xs = 8; // 2u
  static const double sm = 12; // 3u
  static const double md = 16; // 4u
  static const double lg = 24; // 6u
  static const double xl = 32; // 8u
  static const double xxl = 40; // 10u
  static const double xxxl = 56; // 14u

  // Radii — the new visual language uses 20-24px on hero surfaces
  // and 14-16px on inline surfaces. Pill surfaces (chips, badges,
  // strength indicator) use 999.
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radius2xl = 36;
  static const double radiusFull = 999;

  // Common insets.
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(lg, lg, lg, xxl);
}

/// Motion tokens. Centralized so animations stay consistent across
/// the app. We prefer short, opinionated curves over `Curves.ease`
/// everywhere.
abstract final class AppMotion {
  /// Standard tween for hover, press, theme cross-fades. Snappy
  /// but not aggressive.
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);

  /// Curved like `Curves.easeOutCubic` but the curve we use for
  /// surfaces sliding in (login → unlocked transition, sheet
  /// enter).
  static const Cubic enter = Cubic(0.22, 1, 0.36, 1);
  static const Cubic exit = Cubic(0.4, 0, 1, 1);
  static const Cubic emphasized = Cubic(0.3, 0, 0, 1);
}
