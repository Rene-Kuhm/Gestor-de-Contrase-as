import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppSpacing.radiusLg,
        ),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
