import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/update/update_service.dart';

/// Settings section for over-the-air updates.
///
/// The user can tap "Buscar actualizaciones" at any time to query
/// the GitHub Releases API via the native `UpdateChannel`. When an
/// update is found we render a compact changelog and a single
/// "Descargar e instalar" button that streams the APK and hands it
/// off to the system installer. No data leaves the device: the
/// update check is a GET against the public Releases endpoint, the
/// download goes to the app's private files dir, and the
/// installation is a regular `ACTION_VIEW` against the package
/// archive MIME.
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
      // Mark this build as "shown" before we hand control to the
      // system installer. If the user bails out of the install
      // dialog the silent check will re-fire next time and the
      // SnackBar comes back; if they confirm, this widget is gone.
      if (info.releaseId != 0) {
        await widget.service.markInstalled(info.releaseId);
      }
      setState(() => _state = _UpdateState.installing);
      final ok = await widget.service.openInstallPrompt(path);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _state = _UpdateState.failed;
          _errorMessage = 'No pudimos abrir el instalador del sistema. '
              'Verifica que "Fuentes desconocidas" este habilitado.';
        });
        return;
      }
      // The system installer is now in charge. The user confirms
      // there and the new APK replaces the running one — at which
      // point this widget is gone.
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
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actualizaciones',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _VersionRow(
            label: 'Instalada',
            value: _currentVersion,
            highlighted: _state == _UpdateState.upToDate,
          ),
          if (_info != null && (_info!.tagName.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.xs),
            _VersionRow(
              label: 'Remota',
              value: '${_info!.tagName} (release #${_info!.releaseId})',
              highlighted: _state == _UpdateState.updateAvailable,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Las nuevas versiones se publican automaticamente cuando '
            'hay un push a master. Toca el boton para comprobar si '
            'hay una version mas reciente sin desinstalar la app.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildAction(theme),
          if (_state == _UpdateState.updateAvailable && _info != null) ...[
            const SizedBox(height: AppSpacing.md),
            _UpdateAvailablePanel(info: _info!),
          ],
          if (_state == _UpdateState.failed) ...[
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAction(ThemeData theme) {
    switch (_state) {
      case _UpdateState.idle:
      case _UpdateState.upToDate:
        return FilledButton.icon(
          onPressed: _checkForUpdate,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Buscar actualizaciones'),
        );
      case _UpdateState.checking:
        return const _BusyButton(label: 'Buscando...');
      case _UpdateState.updateAvailable:
        return FilledButton.icon(
          onPressed: _downloadAndInstall,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Descargar e instalar'),
        );
      case _UpdateState.downloading:
        return const _BusyButton(label: 'Descargando APK...');
      case _UpdateState.installing:
        return const _BusyButton(label: 'Abriendo instalador...');
      case _UpdateState.failed:
        return FilledButton.icon(
          onPressed: _checkForUpdate,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
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

/// One row in the version table. The "highlighted" flag colours the
/// value cell (green for the installed version when the device is
/// up-to-date, primary for the remote version when an update is
/// waiting). The label is always muted so the value carries the
/// signal.
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
              fontWeight: FontWeight.w600,
              color: highlighted
                  ? theme.colorScheme.primary
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
    final changelog = info.changelog.trim();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Nueva version ${info.tagName}',
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
