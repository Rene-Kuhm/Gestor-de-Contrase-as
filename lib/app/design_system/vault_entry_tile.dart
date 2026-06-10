import 'package:flutter/material.dart';

import '../../features/vault/domain/vault_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_components.dart';

/// Rich card for one vault entry. It keeps the list scannable while
/// making each saved credential feel like a distinct secured item.
class VaultEntryTile extends StatelessWidget {
  const VaultEntryTile({super.key, required this.item, this.onTap});

  final VaultItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDarkHigh : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDarkStrong : AppColors.borderLight;
    final primaryText = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final tertiaryText = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;
    final website = item.website?.trim();
    final hasWebsite = website != null && website.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.accentColor.withValues(alpha: isDark ? 0.36 : 0.22),
                      item.accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: item.accentColor.withValues(alpha: 0.34),
                  ),
                ),
                child: Icon(item.icon, color: item.accentColor, size: 25),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        StrengthBadge(score: item.strengthScore),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        _EntryMetaChip(
                          icon: Icons.person_outline_rounded,
                          label: item.username,
                          color: secondaryText,
                        ),
                        if (hasWebsite)
                          _EntryMetaChip(
                            icon: Icons.language_rounded,
                            label: website,
                            color: secondaryText,
                          )
                        else
                          _EntryMetaChip(
                            icon: Icons.category_outlined,
                            label: item.category.label,
                            color: secondaryText,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: tertiaryText,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            item.lastUpdatedLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: tertiaryText,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: tertiaryText,
                          size: 22,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryMetaChip extends StatelessWidget {
  const _EntryMetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
    final label = score >= 80 ? 'Strong' : (score >= 60 ? 'Fair' : 'Weak');
    return AppPill(label: '$label · $score', tint: tone, compact: true);
  }
}
