import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/localization/app_locale_controller.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/local_encrypted_vault_repository.dart';
import '../../../core/security/vault_security_controller.dart';
import '../../../core/sync/device_registration_repository.dart';
import '../../../core/sync/sync_conflict.dart';
import '../../../core/sync/sync_conflict_resolver.dart';
import '../../../core/sync/device_session_revocation_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.securityController,
    required this.localeController,
    this.conflictResolver,
    this.revocationService,
  });

  final VaultSecurityController securityController;
  final AppLocaleController localeController;

  final SyncConflictResolver? conflictResolver;
  final DeviceSessionRevocationService? revocationService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<SyncConflictRecord>> _conflictsFuture;
  late Future<List<DeviceSessionView>> _devicesFuture;
  bool _revocationInProgress = false;
  bool _currentDeviceRevocationHandled = false;

  @override
  void initState() {
    super.initState();
    _conflictsFuture = _loadConflicts();
    _devicesFuture = _loadDevices();
  }

  Future<void> _openChangeMasterPasswordDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return _ChangeMasterPasswordDialog(
          controller: widget.securityController,
        );
      },
    );
  }

  Future<List<SyncConflictRecord>> _loadConflicts() async {
    final resolver = widget.conflictResolver;
    if (resolver == null) {
      return const [];
    }

    return resolver.readPendingConflicts();
  }

  Future<List<DeviceSessionView>> _loadDevices() async {
    final revocationService = widget.revocationService;
    if (revocationService == null) {
      return const [];
    }

    return revocationService.listDevices();
  }

  void _refreshConflicts() {
    setState(() {
      _conflictsFuture = _loadConflicts();
    });
  }

  void _refreshDevices() {
    setState(() {
      _devicesFuture = _loadDevices();
    });
  }

  Future<void> _revokeDevice(
    BuildContext context,
    DeviceSessionView device,
  ) async {
    final revocationService = widget.revocationService;
    if (revocationService == null) {
      return;
    }

    if (_revocationInProgress) {
      return;
    }

    if (device.isCurrentDevice && !device.isRevoked) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Revoke this device?'),
            content: const Text(
              'Revoking the current device will immediately lock this session. '
              'You will need to unlock again to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Revoke now'),
              ),
            ],
          );
        },
      );

      if (shouldContinue != true) {
        return;
      }
    }

    setState(() {
      _revocationInProgress = true;
    });

    try {
      await revocationService.revokeDevice(deviceId: device.deviceId);

      if (!context.mounted) {
        return;
      }

      if (device.isCurrentDevice) {
        await _handleCurrentDeviceRevocation(
          context,
          status: DeviceSessionStatus.revokedDevice,
          lockReason:
              'Esta sesion se revoco en este dispositivo. Vaulta se bloqueo por seguridad.',
        );
        return;
      }

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsDeviceRevokedMessage)),
      );
      _refreshDevices();
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not revoke this device. Please retry in a few seconds.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _revocationInProgress = false;
        });
      }
    }
  }

  Future<void> _handleCurrentDeviceRevocation(
    BuildContext context, {
    required DeviceSessionStatus status,
    required String lockReason,
  }) async {
    if (_currentDeviceRevocationHandled) {
      return;
    }

    _currentDeviceRevocationHandled = true;

    if (!context.mounted) {
      return;
    }

    final title = switch (status) {
      DeviceSessionStatus.revokedAll => 'Session revoked on all devices',
      _ => 'Current device revoked',
    };
    final message = switch (status) {
      DeviceSessionStatus.revokedAll =>
        'Your account access was revoked for all sessions. This device will lock now for safety.',
      _ =>
        'This device no longer has an active session. Vaulta will lock now for safety.',
    };

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Lock now'),
            ),
          ],
        );
      },
    );

    if (!context.mounted) {
      return;
    }

    await widget.securityController.lock(reason: lockReason);
  }

  Future<void> _revokeAllOtherDevices(BuildContext context) async {
    final revocationService = widget.revocationService;
    if (revocationService == null) {
      return;
    }

    if (_revocationInProgress) {
      return;
    }

    setState(() {
      _revocationInProgress = true;
    });

    try {
      await revocationService.revokeAllOtherDevices();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsRevokeOthersDone)),
      );
      _refreshDevices();
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not revoke other sessions. Please retry in a few seconds.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _revocationInProgress = false;
        });
      }
    }
  }

  String _statusCode(DeviceSessionStatus status) {
    return switch (status) {
      DeviceSessionStatus.active => 'active',
      DeviceSessionStatus.revokedDevice => 'revoked_device',
      DeviceSessionStatus.revokedAll => 'revoked_all',
      DeviceSessionStatus.unknown => 'unknown',
    };
  }

  String _formatSeenAt(BuildContext context, DateTime? date) {
    final l10n = context.l10n;
    if (date == null) {
      return l10n.settingsDeviceNeverSeen;
    }

    return DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_Hm().format(date.toLocal());
  }

  Future<void> _resolveConflict(
    BuildContext context,
    SyncConflictRecord conflict,
    SyncConflictResolution resolution,
  ) async {
    final resolver = widget.conflictResolver;
    if (resolver == null) {
      return;
    }

    final result = await resolver.resolve(
      conflictId: conflict.id,
      resolution: resolution,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    _refreshConflicts();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final securityController = widget.securityController;
    final localeController = widget.localeController;
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
          if (widget.conflictResolver != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppPanel(
              child: FutureBuilder<List<SyncConflictRecord>>(
                future: _conflictsFuture,
                builder: (context, snapshot) {
                  final conflicts =
                      snapshot.data ?? const <SyncConflictRecord>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Sync conflicts',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _refreshConflicts,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (snapshot.connectionState != ConnectionState.done)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: LinearProgressIndicator(),
                        )
                      else if (conflicts.isEmpty)
                        Text(
                          'No pending conflicts. Sync queue is clean.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        for (final conflict in conflicts) ...[
                          _SyncConflictCard(
                            conflict: conflict,
                            onKeepLocal: () {
                              _resolveConflict(
                                context,
                                conflict,
                                SyncConflictResolution.keepLocal,
                              );
                            },
                            onKeepRemote: () {
                              _resolveConflict(
                                context,
                                conflict,
                                SyncConflictResolution.keepRemote,
                              );
                            },
                          ),
                          if (conflict != conflicts.last)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
          if (widget.revocationService != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppPanel(
              child: FutureBuilder<List<DeviceSessionView>>(
                future: _devicesFuture,
                builder: (context, snapshot) {
                  final devices = snapshot.data ?? const <DeviceSessionView>[];
                  DeviceSessionView? currentDevice;
                  for (final device in devices) {
                    if (device.isCurrentDevice) {
                      currentDevice = device;
                      break;
                    }
                  }
                  final currentDeviceRevoked =
                      currentDevice != null && currentDevice.isRevoked;

                  if (snapshot.connectionState == ConnectionState.done &&
                      currentDeviceRevoked &&
                      !_currentDeviceRevocationHandled) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }

                      final status = currentDevice!.status;
                      final reason = switch (status) {
                        DeviceSessionStatus.revokedAll =>
                          'Todas las sesiones se revocaron para esta cuenta. Vaulta se bloqueo por seguridad.',
                        _ =>
                          'Esta sesion se revoco en este dispositivo. Vaulta se bloqueo por seguridad.',
                      };

                      _handleCurrentDeviceRevocation(
                        context,
                        status: status,
                        lockReason: reason,
                      );
                    });
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.settingsSessionsTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.settingsSessionsRefresh,
                            onPressed: _refreshDevices,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.settingsSessionsSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed:
                            securityController.busy || _revocationInProgress
                            ? null
                            : () {
                                _revokeAllOtherDevices(context);
                              },
                        icon: const Icon(Icons.devices_fold_rounded),
                        label: Text(l10n.settingsRevokeOtherDevices),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (snapshot.connectionState != ConnectionState.done)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: LinearProgressIndicator(),
                        )
                      else if (devices.isEmpty)
                        Text(
                          l10n.settingsNoDevices,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        for (final device in devices) ...[
                          _DeviceSessionCard(
                            title: device.deviceName ?? device.deviceId,
                            subtitle:
                                '${device.platform ?? '-'} - ${device.appVersion ?? '-'}',
                            seenAtLabel: _formatSeenAt(
                              context,
                              device.lastSeenAt,
                            ),
                            currentLabel: device.isCurrentDevice
                                ? l10n.settingsCurrentDeviceLabel
                                : null,
                            revoked: device.isRevoked,
                            statusCode: _statusCode(device.status),
                            revokeActionLabel: l10n.settingsRevokeDevice,
                            statusActiveLabel: l10n.settingsSessionStatusActive,
                            statusRevokedLabel:
                                l10n.settingsSessionStatusRevoked,
                            revokingInProgress: _revocationInProgress,
                            currentDeviceRevocationHint:
                                'If you revoke this device, Vaulta will lock immediately.',
                            onRevoke: device.isRevoked
                                ? null
                                : () {
                                    _revokeDevice(context, device);
                                  },
                          ),
                          if (device != devices.last)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
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
                      initialValue:
                          localeController.locale ?? const Locale('es'),
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

class _SyncConflictCard extends StatelessWidget {
  const _SyncConflictCard({
    required this.conflict,
    required this.onKeepLocal,
    required this.onKeepRemote,
  });

  final SyncConflictRecord conflict;
  final VoidCallback onKeepLocal;
  final VoidCallback onKeepRemote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expectedVersion = conflict.expectedVersion?.toString() ?? 'unknown';
    final remoteVersion = conflict.currentVersion?.toString() ?? 'unknown';
    final subtitle =
        conflict.message ?? 'CAS conflict detected while pushing mutation.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_problem_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  conflict.localRecordId,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Local base v$expectedVersion - Remote v$remoteVersion',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onKeepRemote,
                  icon: const Icon(Icons.cloud_done_rounded),
                  label: const Text('Keep remote'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onKeepLocal,
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Keep local'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceSessionCard extends StatelessWidget {
  const _DeviceSessionCard({
    required this.title,
    required this.subtitle,
    required this.seenAtLabel,
    required this.revoked,
    required this.statusCode,
    required this.revokeActionLabel,
    required this.statusActiveLabel,
    required this.statusRevokedLabel,
    required this.revokingInProgress,
    required this.currentDeviceRevocationHint,
    this.currentLabel,
    this.onRevoke,
  });

  final String title;
  final String subtitle;
  final String seenAtLabel;
  final bool revoked;
  final String statusCode;
  final String? currentLabel;
  final String revokeActionLabel;
  final String statusActiveLabel;
  final String statusRevokedLabel;
  final bool revokingInProgress;
  final String currentDeviceRevocationHint;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _SessionStatusBadge(
                label: revoked ? statusRevokedLabel : statusActiveLabel,
                revoked: revoked,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(seenAtLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'status: $statusCode',
            style: theme.textTheme.labelLarge?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (currentLabel case final label?) ...[
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            if (onRevoke != null) ...[
              const SizedBox(height: 4),
              Text(
                currentDeviceRevocationHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ],
          if (onRevoke != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: revokingInProgress ? null : onRevoke,
                icon: const Icon(Icons.block_rounded),
                label: Text(revokeActionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionStatusBadge extends StatelessWidget {
  const _SessionStatusBadge({required this.label, required this.revoked});

  final String label;
  final bool revoked;

  @override
  Widget build(BuildContext context) {
    final color = revoked ? AppColors.warning : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
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
        SnackBar(content: Text(context.l10n.masterPasswordUpdatedSuccess)),
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
