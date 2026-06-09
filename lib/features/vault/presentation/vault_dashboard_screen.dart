import 'package:flutter/material.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/design_system/metric_card.dart';
import '../../../app/design_system/vault_entry_tile.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/vault_repository.dart';
import '../../../core/sync/sync_conflict_resolver.dart';
import '../../sync/presentation/sync_conflicts_sheet.dart';
import '../domain/vault_item.dart';
import '../domain/vault_summary.dart';
import 'vault_entry_detail_screen.dart';
import 'vault_entry_editor_screen.dart';

class VaultDashboardScreen extends StatefulWidget {
  const VaultDashboardScreen({
    super.key,
    required this.repository,
    this.conflictResolver,
  });

  final VaultRepository repository;
  final SyncConflictResolver? conflictResolver;

  @override
  State<VaultDashboardScreen> createState() => _VaultDashboardScreenState();
}

class _VaultDashboardScreenState extends State<VaultDashboardScreen> {
  late Future<({VaultSummary summary, List<VaultItem> items})> _future;
  late final TextEditingController _searchController;
  String _searchQuery = '';
  _VaultFilter _activeFilter = _VaultFilter.all;
  int _pendingConflicts = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _future = _load();
    _loadConflictCount();
  }

  Future<void> _loadConflictCount() async {
    final resolver = widget.conflictResolver;
    if (resolver == null) return;
    final conflicts = await resolver.readPendingConflicts();
    if (mounted) {
      setState(() => _pendingConflicts = conflicts.length);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<({VaultSummary summary, List<VaultItem> items})>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_clock_rounded, size: 42),
                    const SizedBox(height: 16),
                    Text(
                      l10n.dashboardDecryptError,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.dashboardDecryptErrorAdvice,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _refresh, child: Text(l10n.retry)),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final filteredItems = _applyFilters(data.items);

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _createEntry,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.newEntry),
          ),
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
                  child: RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                          sliver: SliverList.list(
                            children: [
                              _DashboardHeader(summary: data.summary),
                              const SizedBox(height: AppSpacing.lg),
                              _HeroSecurityCard(summary: data.summary),
                              const SizedBox(height: AppSpacing.lg),
                              if (_pendingConflicts > 0 &&
                                  widget.conflictResolver != null)
                                _ConflictBanner(
                                  count: _pendingConflicts,
                                  onTap: () async {
                                    await showSyncConflictsSheet(
                                      context: context,
                                      resolver: widget.conflictResolver!,
                                    );
                                    _loadConflictCount();
                                  },
                                ),
                              if (_pendingConflicts > 0 &&
                                  widget.conflictResolver != null)
                                const SizedBox(height: AppSpacing.md),
                              _MetricsGrid(summary: data.summary),
                              const SizedBox(height: AppSpacing.lg),
                              _QuickActions(
                                summary: data.summary,
                                onCreateEntry: _createEntry,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _VaultSection(
                                items: filteredItems,
                                totalItems: data.items.length,
                                searchController: _searchController,
                                activeFilter: _activeFilter,
                                onSearchChanged: (value) {
                                  setState(() => _searchQuery = value);
                                },
                                onFilterChanged: (value) {
                                  setState(() => _activeFilter = value);
                                },
                                onClearFilters: _clearFilters,
                                onCreateEntry: _createEntry,
                                onOpenEntry: _openEntry,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    final summary = await widget.repository.fetchSummary();
    final items = await widget.repository.fetchItems();
    return (summary: summary, items: items);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
    _loadConflictCount();
  }

  List<VaultItem> _applyFilters(List<VaultItem> items) {
    final query = _searchQuery.trim().toLowerCase();

    return items
        .where((item) {
          final matchesQuery =
              query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.username.toLowerCase().contains(query) ||
              (item.website?.toLowerCase().contains(query) ?? false);

          final matchesFilter = switch (_activeFilter) {
            _VaultFilter.all => true,
            _VaultFilter.weak => item.strengthScore < 60,
            _VaultFilter.withNotes =>
              item.notes != null && item.notes!.trim().isNotEmpty,
          };

          return matchesQuery && matchesFilter;
        })
        .toList(growable: false);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _activeFilter = _VaultFilter.all;
    });
  }

  Future<void> _createEntry() async {
    final draft = await Navigator.of(context).push<VaultItem>(
      MaterialPageRoute(builder: (_) => const VaultEntryEditorScreen()),
    );

    if (draft == null) {
      return;
    }

    await widget.repository.saveItem(draft);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.entryCreatedMessage)));
    _refresh();
  }

  Future<void> _openEntry(VaultItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VaultEntryDetailScreen(
          item: item,
          onEdit: () async {
            final updated = await Navigator.of(context).push<VaultItem>(
              MaterialPageRoute(
                builder: (_) => VaultEntryEditorScreen(initialItem: item),
              ),
            );
            if (updated == null) {
              return false;
            }
            await widget.repository.saveItem(updated);
            return true;
          },
          onDelete: () => widget.repository.deleteItem(item.id),
        ),
      ),
    );

    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.vaultUpdatedMessage)));
      _refresh();
    }
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.sync_problem_rounded,
              color: AppColors.warning,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.syncConflictsBannerLabel(count),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.warning),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                l10n.syncConflictsBannerAction,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? AppColors.backgroundDark : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                context.l10n.appTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.dashboardSubtitle,
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
                context.l10n.securityScore,
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
                context.l10n.dashboardHeroTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.dashboardHeroBody,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(
                label: context.l10n.dashboardPillTrustedDevices(
                  summary.connectedDevices,
                ),
              ),
              _Pill(
                label: summary.syncEnabled
                    ? context.l10n.dashboardPillSyncEnabled
                    : context.l10n.dashboardPillSyncDisabled,
              ),
              _Pill(
                label: context.l10n.dashboardPillWeakNeedRotation(
                  summary.weakItems,
                ),
              ),
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
          label: context.l10n.vaultEntries,
          value: '${summary.totalItems}',
          icon: Icons.lock_open_rounded,
          tint: AppColors.ocean,
        ),
        MetricCard(
          label: context.l10n.weakPasswords,
          value: '${summary.weakItems}',
          icon: Icons.warning_amber_rounded,
          tint: AppColors.warning,
        ),
        MetricCard(
          label: context.l10n.reusedItems,
          value: '${summary.reusedItems}',
          icon: Icons.copy_all_rounded,
          tint: AppColors.danger,
        ),
        MetricCard(
          label: context.l10n.trustedDevices,
          value: '${summary.connectedDevices}',
          icon: Icons.devices_rounded,
          tint: AppColors.success,
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.summary, required this.onCreateEntry});

  final VaultSummary summary;
  final Future<void> Function() onCreateEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.priorityActions,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.dashboardQuickActionsSummary,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: onCreateEntry,
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A2D936C),
                child: Icon(
                  Icons.add_moderator_rounded,
                  color: AppColors.success,
                ),
              ),
              title: Text(context.l10n.createEncryptedEntry),
              subtitle: Text(context.l10n.createEncryptedEntrySubtitle),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const Divider(),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AF2C14E),
                child: Icon(
                  Icons.manage_search_rounded,
                  color: AppColors.warning,
                ),
              ),
              title: Text(context.l10n.planNextHardeningStep),
              subtitle: Text(
                summary.syncEnabled
                    ? context.l10n.dashboardRoadmapSyncEnabled
                    : context.l10n.dashboardRoadmapSyncDisabled,
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultSection extends StatelessWidget {
  const _VaultSection({
    required this.items,
    required this.totalItems,
    required this.searchController,
    required this.activeFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onClearFilters,
    required this.onCreateEntry,
    required this.onOpenEntry,
  });

  final List<VaultItem> items;
  final int totalItems;
  final TextEditingController searchController;
  final _VaultFilter activeFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_VaultFilter> onFilterChanged;
  final VoidCallback onClearFilters;
  final Future<void> Function() onCreateEntry;
  final Future<void> Function(VaultItem item) onOpenEntry;

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
                  context.l10n.vaultEntriesSectionTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                totalItems == items.length
                    ? context.l10n.itemsTotal(items.length)
                    : context.l10n.itemsShownOfTotal(items.length, totalItems),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              labelText: context.l10n.searchVault,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClearFilters,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<_VaultFilter>(
            key: ValueKey(activeFilter),
            initialValue: activeFilter,
            decoration: InputDecoration(labelText: context.l10n.filter),
            items: _VaultFilter.values
                .map(
                  (filter) => DropdownMenuItem<_VaultFilter>(
                    value: filter,
                    child: Text(filter.label(context)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                onFilterChanged(value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty && totalItems == 0)
            _EmptyVaultState(onCreateEntry: onCreateEntry)
          else if (items.isEmpty)
            _NoResultsState(onClearFilters: onClearFilters)
          else
            for (var index = 0; index < items.length; index++) ...[
              VaultEntryTile(
                item: items[index],
                onTap: () => onOpenEntry(items[index]),
              ),
              if (index != items.length - 1) const Divider(height: 24),
            ],
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.filter_alt_off_rounded, size: 32),
          const SizedBox(height: 8),
          Text(
            context.l10n.noResultsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.noResultsSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(context.l10n.resetFilters),
          ),
        ],
      ),
    );
  }
}

class _EmptyVaultState extends StatelessWidget {
  const _EmptyVaultState({required this.onCreateEntry});

  final Future<void> Function() onCreateEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.vpn_key_rounded, size: 36, color: AppColors.ocean),
          const SizedBox(height: 12),
          Text(
            context.l10n.emptyVaultTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.emptyVaultSubtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onCreateEntry,
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.createFirstEntry),
          ),
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

enum _VaultFilter { all, weak, withNotes }

extension on _VaultFilter {
  String label(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      _VaultFilter.all => l10n.filterAllEntries,
      _VaultFilter.weak => l10n.filterWeakOnly,
      _VaultFilter.withNotes => l10n.filterWithNotes,
    };
  }
}
