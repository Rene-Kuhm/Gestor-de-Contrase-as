import 'package:flutter/material.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/local_encrypted_vault_repository.dart';
import '../../../core/security/vault_security_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.securityController});

  static const List<_IdleTimeoutPreset> _idleTimeoutPresets = [
    _IdleTimeoutPreset(seconds: 0, label: 'Never', description: 'Disabled'),
    _IdleTimeoutPreset(seconds: 60, label: '1 minute', description: 'Strict'),
    _IdleTimeoutPreset(
      seconds: 300,
      label: '5 minutes',
      description: 'Recommended',
    ),
    _IdleTimeoutPreset(
      seconds: 900,
      label: '15 minutes',
      description: 'Relaxed',
    ),
  ];

  final VaultSecurityController securityController;

  Future<void> _openChangeMasterPasswordDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return _ChangeMasterPasswordDialog(controller: securityController);
      },
    );
  }

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
                            ? 'Usa ${securityController.biometricAvailability.label} para reabrir la sesion local. Si el recovery biometrico del dispositivo sigue vigente, tambien funciona despues de reiniciar la app.'
                            : 'No hay biometria configurada o soportada en este entorno.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: securityController.autoLockOnBackgroundEnabled,
                      onChanged: securityController.busy
                          ? null
                          : (value) {
                              securityController.setAutoLockOnBackgroundEnabled(
                                value,
                              );
                            },
                      title: const Text('Auto-lock al pasar a background'),
                      subtitle: const Text(
                        'Bloquea Vaulta automaticamente si la app queda inactive, paused o detached.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<_IdleTimeoutPreset>(
                      key: ValueKey<int>(securityController.idleTimeoutSeconds),
                      initialValue: _resolveIdlePreset(
                        securityController.idleTimeoutSeconds,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Auto-lock por inactividad en foreground',
                      ),
                      items: _idleTimeoutPresets
                          .map(
                            (preset) => DropdownMenuItem<_IdleTimeoutPreset>(
                              value: preset,
                              child: Text(
                                '${preset.label} - ${preset.description}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: securityController.busy
                          ? null
                          : (preset) {
                              if (preset == null) {
                                return;
                              }
                              securityController.setIdleTimeoutSeconds(
                                preset.seconds,
                              );
                            },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: securityController.busy
                          ? null
                          : securityController.lock,
                      icon: const Icon(Icons.lock_rounded),
                      label: const Text('Lock now'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: securityController.busy
                          ? null
                          : () {
                              _openChangeMasterPasswordDialog(context);
                            },
                      icon: const Icon(Icons.password_rounded),
                      label: const Text('Change master password'),
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

  _IdleTimeoutPreset _resolveIdlePreset(int seconds) {
    for (final preset in _idleTimeoutPresets) {
      if (preset.seconds == seconds) {
        return preset;
      }
    }

    return _idleTimeoutPresets[2];
  }
}

class _IdleTimeoutPreset {
  const _IdleTimeoutPreset({
    required this.seconds,
    required this.label,
    required this.description,
  });

  final int seconds;
  final String label;
  final String description;
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

class _ChangeMasterPasswordDialog extends StatefulWidget {
  const _ChangeMasterPasswordDialog({required this.controller});

  final VaultSecurityController controller;

  @override
  State<_ChangeMasterPasswordDialog> createState() =>
      _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState
    extends State<_ChangeMasterPasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirmation = true;
  String? _formFeedback;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return AlertDialog(
      title: const Text('Change master password'),
      content: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _currentController,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current master password',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureCurrent = !_obscureCurrent;
                        });
                      },
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _newController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New master password',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureNew = !_obscureNew;
                        });
                      },
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _confirmationController,
                  obscureText: _obscureConfirmation,
                  decoration: InputDecoration(
                    labelText: 'Confirm new master password',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmation = !_obscureConfirmation;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmation
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Este cambio vuelve a cifrar todo el vault con una clave nueva.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_formFeedback case final feedback?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.cloud,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      feedback,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: controller.busy
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: controller.busy ? null : _submit,
          child: controller.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _formFeedback = null;
    });

    final changed = await widget.controller.changeMasterPassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
      confirmation: _confirmationController.text,
    );

    if (!mounted) {
      return;
    }

    if (changed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Master password actualizada correctamente.'),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _formFeedback =
          widget.controller.message ??
          'No pudimos cambiar la master password. Revisa los datos e intenta de nuevo.';
    });
  }
}
