import 'package:flutter/material.dart';

import '../../../core/security/demo_vault_repository.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../vault/presentation/vault_dashboard_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.repository});

  final DemoVaultRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      VaultDashboardScreen(repository: widget.repository),
      const _PlaceholderScreen(
        title: 'Autofill & access',
        subtitle: 'Tu flujo de desbloqueo y llenado automatico va a vivir aca.',
      ),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.lock_outline_rounded),
            selectedIcon: Icon(Icons.lock_rounded),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: Icon(Icons.flash_on_outlined),
            selectedIcon: Icon(Icons.flash_on_rounded),
            label: 'Access',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
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
