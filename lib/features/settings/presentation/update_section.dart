import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/design_system/app_components.dart';
import '../../../app/design_system/app_panel.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/update/update_service.dart';
import '../../../l10n/app_localizations.dart';

class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key, required this.service});

  final UpdateService service;

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

enum _UpdateState {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  installing,
  failed,
}

class _UpdateSectionState extends State<UpdateSection> {
  _UpdateState _state = _UpdateState.idle;
  String? _errorMessage;
  UpdateInfo? _info;
  String _currentVersion = '…';

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentVersion());
  }

  Future<void> _loadCurrentVersion() async {
    final v = await widget.service.currentVersion();
    if (!mounted) return;
    setState(() => _currentVersion = v);
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _state = _UpdateState.checking;
      _errorMessage = null;
    });
    try {
      final info = await widget.service.checkForUpdate();
      if (!mounted) return;
      if (info.available) {
        setState(() {
          _state = _UpdateState.updateAvailable;
          _info = info;
        });
      } else {
        setState(() {
          _state = _UpdateState.upToDate;
          _info = info;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.failed;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    final info = _info;
    if (info == null) return;
    setState(() {
      _state = _UpdateState.downloading;
      _errorMessage = null;
    });
    try {
      final path = await widget.service.downloadApk(info);
      if (!mounted) return;
      setState(() => _state = _UpdateState.installing);
      final ok = await widget.service.openInstallPrompt(path);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _state = _UpdateState.failed;
          _errorMessage = context.l10n.updateInstallerFailed;
        });
        return;
      }
      await widget.service.markBuildPrompted(info);
      setState(() => _state = _UpdateState.idle);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.failed;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.updateTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _VersionRow(
            label: l10n.updateInstalled,
            value: _currentVersion,
            highlighted: _state == _UpdateState.upToDate,
          ),
          if (_info != null && (_info!.tagName.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.xxs),
            _VersionRow(
              label: l10n.updateRemote,
              value:
                  '${_info!.tagName} (${l10n.updateReleaseId(_info!.releaseId)})',
              highlighted: _state == _UpdateState.updateAvailable,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.updateDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildAction(theme, l10n),
          if (_state == _UpdateState.upToDate) ...[
            const SizedBox(height: AppSpacing.md),
            _UpToDateBanner(),
          ],
          if (_state == _UpdateState.updateAvailable && _info != null) ...[
            const SizedBox(height: AppSpacing.md),
            _UpdateAvailablePanel(info: _info!),
          ],
          if (_state == _UpdateState.failed && _errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorBanner(message: _errorMessage!),
          ],
        ],
      ),
    );
  }

  Widget _buildAction(ThemeData theme, AppLocalizations l10n) {
    switch (_state) {
      case _UpdateState.idle:
      case _UpdateState.upToDate:
        return FilledButton.icon(
          onPressed: _checkForUpdate,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.updateCheck),
        );
      case _UpdateState.checking:
        return _BusyButton(label: l10n.updateChecking);
      case _UpdateState.updateAvailable:
        return FilledButton.icon(
          onPressed: _downloadAndInstall,
          icon: const Icon(Icons.download_rounded),
          label: Text(l10n.updateDownload),
        );
      case _UpdateState.downloading:
        return _BusyButton(label: l10n.updateDownloading);
      case _UpdateState.installing:
        return _BusyButton(label: l10n.updateInstalling);
      case _UpdateState.failed:
        return FilledButton.icon(
          onPressed: _checkForUpdate,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.updateRetry),
        );
    }
  }
}

class _BusyButton extends StatelessWidget {
  const _BusyButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: null,
      icon: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      label: Text(label),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlighted
                  ? AppColors.crimsonBright
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _UpdateAvailablePanel extends StatelessWidget {
  const _UpdateAvailablePanel({required this.info});
  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final changelog = info.changelog.trim();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.crimson.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.crimson.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.system_update_alt_rounded,
                color: AppColors.crimsonBright,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.updateAvailableVersion(info.tagName),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (changelog.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              changelog,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _UpToDateBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBanner(
      tone: AppBannerTone.success,
      icon: Icons.check_circle_outline_rounded,
      message: '${l10n.updateUpToDateTitle} - ${l10n.updateUpToDateBody}',
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.updateErrorTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
