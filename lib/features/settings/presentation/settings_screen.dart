import 'package:flutter/material.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/demo_vault_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform security roadmap',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  DemoVaultRepository.securityPlan.notes,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _CapabilityRow(
                  title: 'Secure storage',
                  enabled: DemoVaultRepository.securityPlan.secureStorage,
                ),
                _CapabilityRow(
                  title: 'Biometric unlock',
                  enabled: DemoVaultRepository.securityPlan.biometricUnlock,
                ),
                _CapabilityRow(
                  title: 'Hardware-backed keys',
                  enabled: DemoVaultRepository.securityPlan.hardwareBackedKeys,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.title, required this.enabled});

  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            enabled
                ? Icons.verified_user_rounded
                : Icons.radio_button_unchecked,
            color: enabled ? Colors.green : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        ],
      ),
    );
  }
}
