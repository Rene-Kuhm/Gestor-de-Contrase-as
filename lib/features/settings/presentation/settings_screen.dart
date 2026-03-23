import 'package:flutter/material.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/localization/app_locale_controller.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/local_encrypted_vault_repository.dart';
import '../../../core/security/vault_security_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.securityController,
    required this.localeController,
  });

  final VaultSecurityController securityController;
  final AppLocaleController localeController;

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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final idleTimeoutPresets = <_IdleTimeoutPreset>[
      _IdleTimeoutPreset(
        seconds: 0,
        label: l10n.idleNever,
        description: l10n.idleDisabled,
      ),
      _IdleTimeoutPreset(
        seconds: 60,
        label: l10n.idleOneMinute,
        description: l10n.idleStrict,
      ),
      _IdleTimeoutPreset(
        seconds: 300,
        label: l10n.idleFiveMinutes,
        description: l10n.idleRecommended,
      ),
      _IdleTimeoutPreset(
        seconds: 900,
        label: l10n.idleFifteenMinutes,
        description: l10n.idleRelaxed,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
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
                      l10n.settingsLocalUnlockPostureTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.settingsLocalUnlockPostureDescription,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _CapabilityRow(
                      title: l10n.settingsMasterPasswordCreated,
                      enabled: true,
                    ),
                    _CapabilityRow(
                      title: l10n.settingsBiometricsAvailable,
                      enabled: securityController.canOfferBiometricToggle,
                    ),
                    _CapabilityRow(
                      title: l10n.settingsBiometricsEnabled,
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
                      title: Text(l10n.settingsUnlockWithBiometrics),
                      subtitle: Text(
                        securityController.canOfferBiometricToggle
                            ? l10n.settingsBiometricSupportedSubtitle(
                                securityController.biometricAvailability.label,
                              )
                            : l10n.settingsBiometricUnavailableSubtitle,
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
                      title: Text(l10n.settingsAutoLockBackgroundTitle),
                      subtitle: Text(l10n.settingsAutoLockBackgroundSubtitle),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<_IdleTimeoutPreset>(
                      key: ValueKey<int>(securityController.idleTimeoutSeconds),
                        initialValue: _resolveIdlePreset(
                          securityController.idleTimeoutSeconds,
                          idleTimeoutPresets,
                        ),
                      decoration: InputDecoration(
                         labelText: l10n.settingsIdleTimeoutLabel,
                       ),
                      items: idleTimeoutPresets
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
                       label: Text(l10n.settingsLockNow),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: securityController.busy
                          ? null
                          : () {
                              _openChangeMasterPasswordDialog(context);
                            },
                      icon: const Icon(Icons.password_rounded),
                       label: Text(l10n.settingsChangeMasterPassword),
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
                  l10n.settingsRoadmapTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.settingsRoadmapNotes,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _CapabilityRow(
                  title: l10n.settingsSecureStorage,
                  enabled:
                      LocalEncryptedVaultRepository.securityPlan.secureStorage,
                ),
                _CapabilityRow(
                  title: l10n.settingsBiometricUnlock,
                  enabled: LocalEncryptedVaultRepository
                      .securityPlan
                      .biometricUnlock,
                ),
                _CapabilityRow(
                  title: l10n.settingsHardwareBackedKeys,
                  enabled: LocalEncryptedVaultRepository
                      .securityPlan
                      .hardwareBackedKeys,
                ),
                _CapabilityRow(
                  title: l10n.settingsVaultEncryptionReady,
                  enabled: LocalEncryptedVaultRepository
                      .securityPlan
                      .vaultEncryptionReady,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPanel(
            child: AnimatedBuilder(
              animation: localeController,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.languageSectionTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<Locale>(
                      key: ValueKey<String>(
                        localeController.locale?.languageCode ?? 'es',
                      ),
                      initialValue: localeController.locale ?? const Locale('es'),
                      decoration: InputDecoration(
                        labelText: l10n.languageSelectorLabel,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: const Locale('es'),
                          child: Text(l10n.languageSpanish),
                        ),
                        DropdownMenuItem(
                          value: const Locale('en'),
                          child: Text(l10n.languageEnglish),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        localeController.setLocale(value);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  _IdleTimeoutPreset _resolveIdlePreset(
    int seconds,
    List<_IdleTimeoutPreset> presets,
  ) {
    for (final preset in presets) {
      if (preset.seconds == seconds) {
        return preset;
      }
    }

    return presets[2];
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
      title: Text(context.l10n.changeMasterPasswordTitle),
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
                    labelText: context.l10n.changeMasterPasswordCurrent,
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
                    labelText: context.l10n.changeMasterPasswordNew,
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
                    labelText: context.l10n.changeMasterPasswordConfirm,
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
                  context.l10n.changeMasterPasswordHint,
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
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: controller.busy ? null : _submit,
          child: controller.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.apply),
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
        SnackBar(
          content: Text(context.l10n.masterPasswordUpdatedSuccess),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _formFeedback =
          widget.controller.message ??
          context.l10n.changeMasterPasswordErrorFallback;
    });
  }
}
