import 'package:flutter/material.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/local_encrypted_vault_repository.dart';
import '../../../core/security/vault_security_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.securityController});

  final VaultSecurityController securityController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppPanel(
            child: AnimatedBuilder(
              animation: securityController,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local unlock posture',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Vaulta ya guarda el estado sensible en Keychain / Keystore y usa biometria del sistema cuando el equipo lo permite.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _CapabilityRow(
                      title: 'Master password creada',
                      enabled: true,
                    ),
                    _CapabilityRow(
                      title: 'Biometria disponible',
                      enabled: securityController.canOfferBiometricToggle,
                    ),
                    _CapabilityRow(
                      title: 'Biometria activada',
                      enabled: securityController.biometricEnabled,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: securityController.biometricEnabled,
                      onChanged: securityController.busy
                          ? null
                          : (value) {
                              securityController.setBiometricEnabled(value);
                            },
                      title: const Text('Unlock with biometrics'),
                      subtitle: Text(
                        securityController.canOfferBiometricToggle
                            ? 'Usa ${securityController.biometricAvailability.label} para reabrir la sesion local. Despues de cerrar la app por completo, la clave del vault vuelve a requerir master password.'
                            : 'No hay biometria configurada o soportada en este entorno.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: securityController.busy
                          ? null
                          : securityController.lock,
                      icon: const Icon(Icons.lock_rounded),
                      label: const Text('Lock now'),
                    ),
                    if (securityController.message case final message?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.cloud,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
                  LocalEncryptedVaultRepository.securityPlan.notes,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _CapabilityRow(
                  title: 'Secure storage',
                  enabled:
                      LocalEncryptedVaultRepository.securityPlan.secureStorage,
                ),
                _CapabilityRow(
                  title: 'Biometric unlock',
                  enabled: LocalEncryptedVaultRepository
                      .securityPlan
                      .biometricUnlock,
                ),
                _CapabilityRow(
                  title: 'Hardware-backed keys',
                  enabled: LocalEncryptedVaultRepository
                      .securityPlan
                      .hardwareBackedKeys,
                ),
                _CapabilityRow(
                  title: 'Vault item encryption wired end-to-end',
                  enabled: LocalEncryptedVaultRepository
                      .securityPlan
                      .vaultEncryptionReady,
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
