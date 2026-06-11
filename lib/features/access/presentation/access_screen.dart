import 'package:flutter/material.dart';

import '../../../app/design_system/app_components.dart';
import '../../../app/design_system/app_panel.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/vault_repository.dart';
import '../../../core/security/vault_security_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Access & Autofill section.
///
/// The platform-level AutofillService integration lives in
/// `android/app/src/main/.../AutofillService.kt`; this screen is
/// the in-app control center: it explains the setup, walks the
/// user through the platform settings, and shows the unlock state.
class AccessScreen extends StatelessWidget {
  /// Creates the "Access & Autofill" tab. Both [securityController]
  /// and [repository] are required so this tab never silently
  /// no-ops when wired without them.
  const AccessScreen({
    super.key,
    required this.securityController,
    required this.repository,
  });

  /// Security controller used to render the unlocked/locked pill
  /// and to trigger an explicit lock from this screen.
  final VaultSecurityController securityController;

  /// Vault repository. Currently unused at the UI layer but kept on
  /// the constructor for parity with the other tabs and so future
  /// entries (for example, "recently autofilled") can read it
  /// without a refactor.
  final VaultRepository repository;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const SizedBox(height: AppSpacing.md),
            AppSectionHeader(
              eyebrow: l10n.accessEyebrow,
              title: l10n.accessTitle,
              subtitle: l10n.accessSubtitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            _AutofillHeroCard(),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.accessSetupTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.accessSetupSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0;
                      i < _setupSteps(l10n).length;
                      i++) ...[
                    if (i != 0) const Divider(height: AppSpacing.lg),
                    _SetupStepRow(
                      step: i + 1,
                      title: _setupSteps(l10n)[i].$1,
                      body: _setupSteps(l10n)[i].$2,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.accessUnlockPostureTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.accessUnlockPostureBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AnimatedBuilder(
                    animation: securityController,
                    builder: (context, _) {
                      final tone = securityController.isUnlocked
                          ? AppPillTint.success
                          : AppPillTint.warning;
                      final label = securityController.isUnlocked
                          ? l10n.accessUnlocked
                          : l10n.accessLocked;
                      return AppPill(label: label, tint: tone);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonalIcon(
                    onPressed: securityController.isUnlocked
                        ? securityController.lock
                        : null,
                    icon: const Icon(Icons.lock_rounded),
                    label: Text(l10n.accessLockNow),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.accessRoadmapTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.accessRoadmapBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _AutofillHeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AppGlassSurface(
      tint: AppGlassTint.strong,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.crimson,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.paperDark,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.accessHeroTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.accessHeroBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppPill(
                icon: Icons.android_rounded,
                label: l10n.accessPlatformAndroid,
                tint: AppPillTint.crimson,
              ),
              AppPill(
                icon: Icons.shield_moon_rounded,
                label: l10n.accessPlatformBiometrics,
                tint: AppPillTint.success,
              ),
              AppPill(
                icon: Icons.cloud_off_rounded,
                label: l10n.accessPlatformOffline,
                tint: AppPillTint.neutral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetupStepRow extends StatelessWidget {
  const _SetupStepRow({
    required this.step,
    required this.title,
    required this.body,
  });

  final int step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            '$step',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.paperDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

List<(String, String)> _setupSteps(AppLocalizations l10n) {
  return [
    (l10n.accessSetupStep1Title, l10n.accessSetupStep1Body),
    (l10n.accessSetupStep2Title, l10n.accessSetupStep2Body),
    (l10n.accessSetupStep3Title, l10n.accessSetupStep3Body),
  ];
}
