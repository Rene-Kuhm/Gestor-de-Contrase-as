import 'package:flutter/material.dart';

/// Vaulta design tokens.
///
/// The product is dark-first, "editorial glassmorphism" with a single
/// accent (`crimson` = `#9B1B1F`) drawn from the brand mark in
/// `assets/brand/cv-logomark.svg`. The mark uses a second highlight
/// (`gold` = `#F2C70F`) for the keyhole / bar — we expose it as a
/// utility token but never use it as a primary surface color.
abstract final class AppColors {
  // --- Brand ---------------------------------------------------------------

  /// Primary accent. The "V" of the Vaulta logomark, the security
  /// score ring, the primary action buttons.
  static const Color crimson = Color(0xFFB81E25);
  static const Color crimsonBright = Color(0xFFE04A4F);
  static const Color crimsonDeep = Color(0xFF7A0A0E);

  /// Secondary accent reserved for the keyhole / bar of the logomark
  /// and for success highlights in the score ring. Never use as a
  /// primary fill.
  static const Color gold = Color(0xFFF2C70F);

  // --- Dark surfaces -------------------------------------------------------

  /// Canvas behind everything in dark mode. Not pure black so the
  /// crimson glow orbs have something to sit on.
  static const Color backgroundDark = Color(0xFF0A0A0C);
  static const Color surfaceDark = Color(0xFF141418);
  static const Color surfaceDarkHigh = Color(0xFF1C1C22);
  static const Color surfaceDarkHighest = Color(0xFF25252C);

  /// Translucent fills used by `AppPanel.glass` on top of dark
  /// backgrounds. Combined with the blur from `BackdropFilter` in
  /// `AppGlassSurface` to produce the editorial-glassmorphism feel.
  static const Color glassDarkLow = Color(0x1414171E);
  static const Color glassDarkMid = Color(0x1F14141A);
  static const Color glassDarkHigh = Color(0x3314151E);

  // --- Light surfaces ------------------------------------------------------

  /// Light mode is opt-in (system / manual) but the app's identity
  /// lives in dark. We keep the light surfaces quiet and tinted so
  /// the crimson still reads as the same brand.
  static const Color backgroundLight = Color(0xFFFAF7F2);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightHigh = Color(0xFFF1ECE3);
  static const Color surfaceLightHighest = Color(0xFFE7E0D2);

  // --- Borders -------------------------------------------------------------

  /// Hairline strokes. The new visual language uses 1px borders
  /// with a 6-8% white tint in dark mode — never #FFFFFF solid.
  static const Color borderDark = Color(0x14FFFFFF);
  static const Color borderDarkStrong = Color(0x29FFFFFF);
  static const Color borderLight = Color(0x14000000);
  static const Color borderLightStrong = Color(0x29000000);

  // --- Text ----------------------------------------------------------------

  static const Color textPrimaryDark = Color(0xFFF5F2EA);
  static const Color textSecondaryDark = Color(0xCCF5F2EA);
  static const Color textTertiaryDark = Color(0x99F5F2EA);

  /// Off-white "paper" tone. This is the same color as the body of
  /// the lock in the logomark — it ties the in-app type to the mark.
  static const Color paperDark = Color(0xFFF5F2EA);
  static const Color ink = Color(0xFF0A0A0C);

  static const Color textPrimaryLight = Color(0xFF0A0A0C);
  static const Color textSecondaryLight = Color(0xCC0A0A0C);
  static const Color textTertiaryLight = Color(0x990A0A0C);

  // --- Status --------------------------------------------------------------

  /// Status colors are kept restrained: success is a desaturated teal
  /// so it never competes with crimson; warning is a desaturated
  /// amber; danger reuses crimson so destructive actions feel
  /// visually related to the brand.
  static const Color success = Color(0xFF4FB58E);
  static const Color warning = Color(0xFFE2A341);
  static const Color danger = Color(0xFFC0392B);
  static const Color info = Color(0xFF6E8FB2);

  // --- Brand glow (for ambient orbs) --------------------------------------

  /// The crimson orbs we render in the login / dashboard. Kept
  /// translucent so they only "tint" the background, never overwrite
  /// it.
  static const Color crimsonGlow = Color(0x339B1B1F);
  static const Color goldGlow = Color(0x22F2C70F);

  // --- Legacy aliases ------------------------------------------------------
  //
  // A few call sites still reference the old semantic names. We
  // keep them so the rewrite can land incrementally without breaking
  // untouched files. New code should use the semantic names above.
  static const Color brand = crimson;
  static const Color brandLight = crimsonBright;
  static const Color brandSubtle = Color(0x33B81E25);
  static const Color brandSubtleDark = Color(0x447A0A0E);

  static const Color background = backgroundLight;
  static const Color surface = surfaceLight;
  static const Color surfaceMuted = surfaceLightHigh;
  static const Color surfaceMutedDark = surfaceDarkHigh;

  static const Color border = borderLight;
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;

  static const Color mint = success;
  static const Color sand = backgroundLight;
  static const Color cloud = surfaceLightHigh;
  static const Color night = backgroundDark;
  static const Color ocean = crimson;
  static const Color slate = Color(0xFF52525B);
  static const Color steel = textSecondaryLight;
}
