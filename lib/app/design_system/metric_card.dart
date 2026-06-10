import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_panel.dart';

/// One cell in the dashboard's 2x2 metrics grid. Tinted icon, big
/// number, label. The previous version was a 1px-bordered card; the
/// new one uses a subtle glass surface so it sits well in the dark
/// gradient hero behind it.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return AppGlassSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppSpacing.radiusLg,
      tint: AppGlassTint.regular,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: isDark ? 0.18 : 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, size: 16, color: tint),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
