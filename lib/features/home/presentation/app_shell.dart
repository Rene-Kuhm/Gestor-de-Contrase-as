import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/localization/app_locale_controller.dart';
import '../../../app/localization/l10n.dart';
import '../../../core/security/vault_security_controller.dart';
import '../../../core/sync/device_session_revocation_service.dart';
import '../../../core/security/vault_repository.dart';
import '../../../core/sync/sync_conflict_resolver.dart';
import '../../../core/update/update_service.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../vault/presentation/vault_dashboard_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.repository,
    required this.securityController,
    required this.localeController,
    this.conflictResolver,
    this.revocationService,
  });

  final VaultRepository repository;
  final VaultSecurityController securityController;
  final AppLocaleController localeController;
  final SyncConflictResolver? conflictResolver;
  final DeviceSessionRevocationService? revocationService;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late final UpdateService _updateService = UpdateService(
    owner: 'Rene-Kuhm',
    repo: 'Gestor-de-Contrase-as',
  );

  @override
  void initState() {
    super.initState();
    // Silent auto-check after the user lands on the dashboard. We
    // never block the UI on this; the worst case is a SnackBar that
    // pops up a few seconds later if a new build is available.
    unawaited(_silentCheckForUpdate());
  }

  Future<void> _silentCheckForUpdate() async {
    try {
      final info = await _updateService.checkForUpdate();
      if (!info.available) return;
      // Defer the SnackBar until after the current frame so the
      // ScaffoldMessenger is in the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Nueva version ${info.tagName} disponible'),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Actualizar',
              onPressed: () => _downloadAndInstall(info),
            ),
          ),
        );
      });
    } catch (error, stack) {
      debugPrint('[Vaulta/Update] silent check failed: $error\n$stack');
    }
  }

  Future<void> _downloadAndInstall(UpdateInfo info) async {
    final messenger = _scaffoldMessengerKey.currentState;
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Descargando actualizacion...'),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final path = await _updateService.downloadApk(info);
      if (!mounted) return;
      final ok = await _updateService.openInstallPrompt(path);
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Confirma la instalacion en la pantalla del sistema.'
                : 'No pudimos abrir el instalador. Andá a Ajustes para '
                    'habilitar "Fuentes desconocidas" y volve a intentar.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Error al actualizar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screens = [
      VaultDashboardScreen(
        repository: widget.repository,
        conflictResolver: widget.conflictResolver,
      ),
      const _PlaceholderScreen(
        title: 'Autofill & access',
        subtitle: 'Tu flujo de desbloqueo y llenado automatico va a vivir aca.',
      ),
      SettingsScreen(
        securityController: widget.securityController,
        localeController: widget.localeController,
        conflictResolver: widget.conflictResolver,
        revocationService: widget.revocationService,
      ),
    ];

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.lock_outline_rounded),
              selectedIcon: Icon(Icons.lock_rounded),
              label: l10n.navVault,
            ),
            NavigationDestination(
              icon: Icon(Icons.flash_on_outlined),
              selectedIcon: Icon(Icons.flash_on_rounded),
              label: l10n.navAccess,
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.layers_outlined,
                size: 52,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
