import 'package:flutter/material.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/design_system/metric_card.dart';
import '../../../app/design_system/vault_entry_tile.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/vault_repository.dart';
import '../domain/vault_item.dart';
import '../domain/vault_summary.dart';

class VaultDashboardScreen extends StatelessWidget {
  const VaultDashboardScreen({super.key, required this.repository});

  final VaultRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({VaultSummary summary, List<VaultItem> items})>(
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;

        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF102636)
                      : const Color(0xFFDDF4F0),
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
            child: Stack(
              children: [
                const _AmbientOrbs(),
                SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        sliver: SliverList.list(
                          children: [
                            _DashboardHeader(summary: data.summary),
                            const SizedBox(height: AppSpacing.lg),
                            _HeroSecurityCard(summary: data.summary),
                            const SizedBox(height: AppSpacing.lg),
                            _MetricsGrid(summary: data.summary),
                            const SizedBox(height: AppSpacing.lg),
                            _QuickActions(summary: data.summary),
                            const SizedBox(height: AppSpacing.lg),
                            _RecentVaultSection(items: data.items),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<({VaultSummary summary, List<VaultItem> items})> _load() async {
    final summary = await repository.fetchSummary();
    final items = await repository.fetchRecentItems();
    return (summary: summary, items: items);
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.summary});

  final VaultSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vaulta',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your encrypted control room',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${summary.securityScore}%',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Security score',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroSecurityCard extends StatelessWidget {
  const _HeroSecurityCard({required this.summary});

  final VaultSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.ink, AppColors.ocean],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_moon_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Protected by system hardware',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'El vault local ya cifra cada item con AES-256-GCM. Biometria persistente entre reinicios, rekeying y sync confiable siguen explicitamente pendientes.',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(label: '${summary.connectedDevices} devices trusted'),
              _Pill(
                label: summary.syncEnabled
                    ? 'Secure sync on'
                    : 'Offline encrypted vault',
              ),
              _Pill(label: '${summary.weakItems} passwords need rotation'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary});

  final VaultSummary summary;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        MetricCard(
          label: 'Vault entries',
          value: '${summary.totalItems}',
          icon: Icons.lock_open_rounded,
          tint: AppColors.ocean,
        ),
        MetricCard(
          label: 'Weak passwords',
          value: '${summary.weakItems}',
          icon: Icons.warning_amber_rounded,
          tint: AppColors.warning,
        ),
        MetricCard(
          label: 'Reused items',
          value: '${summary.reusedItems}',
          icon: Icons.copy_all_rounded,
          tint: AppColors.danger,
        ),
        MetricCard(
          label: 'Trusted devices',
          value: '${summary.connectedDevices}',
          icon: Icons.devices_rounded,
          tint: AppColors.success,
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.summary});

  final VaultSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Priority actions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Una base profesional arranca por seguridad visible y decisiones de plataforma explicitas.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0x1AF2C14E),
              child: Icon(Icons.fingerprint_rounded, color: AppColors.warning),
            ),
            title: const Text('Enable biometric recovery'),
            subtitle: const Text(
              'Keep real device-backed key wrapping separate from the master password flow.',
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0x1A2D936C),
              child: Icon(Icons.cloud_sync_rounded, color: AppColors.success),
            ),
            title: const Text('Review sync trust model'),
            subtitle: Text(
              summary.syncEnabled
                  ? 'Cross-device sync currently planned.'
                  : 'Encrypted local-only mode selected.',
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentVaultSection extends StatelessWidget {
  const _RecentVaultSection({required this.items});

  final List<VaultItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent vault activity',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('See all')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < items.length; index++) ...[
            VaultEntryTile(item: items[index]),
            if (index != items.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _AmbientOrbs extends StatelessWidget {
  const _AmbientOrbs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -20,
            child: _Orb(
              color: AppColors.mint.withValues(alpha: 0.24),
              size: 180,
            ),
          ),
          Positioned(
            top: 220,
            left: -70,
            child: _Orb(
              color: AppColors.ocean.withValues(alpha: 0.14),
              size: 160,
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
