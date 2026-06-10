import 'package:flutter/material.dart';

import '../../features/vault/domain/vault_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_components.dart';

/// One row in the vault list. Replaces the previous "Row of icons
/// + text + badge" with a cleaner hero that lets the title breathe.
class VaultEntryTile extends StatelessWidget {
  const VaultEntryTile({super.key, required this.item, this.onTap});

  final VaultItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(
                    alpha: isDark ? 0.18 : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(item.icon, color: item.accentColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.username} · ${item.category.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StrengthBadge(score: item.strengthScore),
                  const SizedBox(height: 4),
                  Text(
                    item.lastUpdatedLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Strength indicator. Three tiers only; the score sits next to a
/// single colored dot. The previous "colored text + dot" was hard to
/// scan when there were many items.
class StrengthBadge extends StatelessWidget {
  const StrengthBadge({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final tone = score >= 80
        ? AppPillTint.success
        : (score >= 60 ? AppPillTint.warning : AppPillTint.danger);
    final label = score >= 80
        ? 'Strong'
        : (score >= 60 ? 'Fair' : 'Weak');
    return AppPill(
      label: '$label · $score',
      tint: tone,
      compact: true,
    );
  }
}
