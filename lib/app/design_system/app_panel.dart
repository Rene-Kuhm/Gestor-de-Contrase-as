import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Glass surface used by the login / onboarding / hero surfaces.
///
/// On dark backgrounds we render a tinted fill, a 1px hairline
/// border, and (where the platform supports it) a [BackdropFilter]
/// for the editorial-glassmorphism look. On light backgrounds the
/// blur is invisible against paper, so we fall back to a solid
/// tinted fill.
///
/// Every panel in the redesign goes through [AppGlassSurface]; this
/// is the only place that knows how to render a glass card. New
/// variants go here, not in screen files.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppSpacing.radiusXl,
    this.tint = AppGlassTint.regular,
    this.border = true,
  }) : _blurred = true;

  /// Static (non-blurred) variant. Use when the parent stack is too
  /// expensive to wrap in a [BackdropFilter] (e.g. inside a
  /// `SliverList` with many tiles). Visually identical to the
  /// blurred variant on a solid background.
  const AppGlassSurface.solid({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppSpacing.radiusXl,
    this.tint = AppGlassTint.regular,
    this.border = true,
  }) : _blurred = false;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final AppGlassTint tint;
  final bool border;
  final bool _blurred;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = _resolveFill(isDark);
    final stroke = _resolveStroke(isDark);

    final radius = BorderRadius.circular(borderRadius);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: border
          ? BorderSide(color: stroke, width: 1)
          : BorderSide.none,
    );

    final container = AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.emphasized,
      decoration: ShapeDecoration(
        color: fill,
        shape: shape,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (!_blurred || !isDark) {
      return container;
    }
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: container,
      ),
    );
  }

  Color _resolveFill(bool isDark) {
    if (isDark) {
      return switch (tint) {
        AppGlassTint.subtle => AppColors.glassDarkLow,
        AppGlassTint.regular => AppColors.glassDarkMid,
        AppGlassTint.strong => AppColors.glassDarkHigh,
      };
    }
    return switch (tint) {
      AppGlassTint.subtle => AppColors.surfaceLight,
      AppGlassTint.regular => AppColors.surfaceLight,
      AppGlassTint.strong => AppColors.surfaceLightHigh,
    };
  }

  Color _resolveStroke(bool isDark) {
    return isDark ? AppColors.borderDark : AppColors.borderLight;
  }
}

enum AppGlassTint { subtle, regular, strong }

/// Convenience for screens that still want the old "panel" affordance
/// but get the new visual language for free.
class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius,
    this.tint = AppGlassTint.regular,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? borderRadius;
  final AppGlassTint tint;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: padding,
      borderRadius: borderRadius ?? AppSpacing.radiusLg,
      tint: tint,
      child: child,
    );
  }
}
