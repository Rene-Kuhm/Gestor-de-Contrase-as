import 'package:flutter/material.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/sync/sync_conflict.dart';
import '../../../core/sync/sync_conflict_resolver.dart';

Future<void> showSyncConflictsSheet({
  required BuildContext context,
  required SyncConflictResolver resolver,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (context) => _SyncConflictsSheet(resolver: resolver),
  );
}

class _SyncConflictsSheet extends StatefulWidget {
  const _SyncConflictsSheet({required this.resolver});

  final SyncConflictResolver resolver;

  @override
  State<_SyncConflictsSheet> createState() => _SyncConflictsSheetState();
}

class _SyncConflictsSheetState extends State<_SyncConflictsSheet> {
  late Future<List<SyncConflictRecord>> _future;
  final Set<String> _resolving = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.resolver.readPendingConflicts();
  }

  Future<void> _resolve(
    String conflictId,
    SyncConflictResolution resolution,
  ) async {
    if (_resolving.contains(conflictId)) return;
    setState(() => _resolving.add(conflictId));
    try {
      await widget.resolver.resolve(
        conflictId: conflictId,
        resolution: resolution,
      );
    } finally {
      if (mounted) {
        setState(() {
          _resolving.remove(conflictId);
          _reload();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.sync_problem_rounded,
                  color: AppColors.warning,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.syncConflictsTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
            child: Text(
              l10n.syncConflictsSubtitle,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Divider(
            color: isDark ? AppColors.borderDark : AppColors.border,
            height: 1,
          ),
          Expanded(
            child: FutureBuilder<List<SyncConflictRecord>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final conflicts = snapshot.data ?? [];

                if (conflicts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.syncConflictsEmpty,
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: conflicts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final conflict = conflicts[index];
                    return _ConflictTile(
                      conflict: conflict,
                      resolving: _resolving.contains(conflict.id),
                      onKeepLocal: () =>
                          _resolve(conflict.id, SyncConflictResolution.keepLocal),
                      onKeepRemote: () =>
                          _resolve(conflict.id, SyncConflictResolution.keepRemote),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictTile extends StatelessWidget {
  const _ConflictTile({
    required this.conflict,
    required this.resolving,
    required this.onKeepLocal,
    required this.onKeepRemote,
  });

  final SyncConflictRecord conflict;
  final bool resolving;
  final VoidCallback onKeepLocal;
  final VoidCallback onKeepRemote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _KindChip(kind: conflict.kind),
              const Spacer(),
              Text(
                _formatDate(conflict.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _VersionRow(
            label: l10n.syncConflictLocalVersion,
            version: conflict.localSnapshot?.version,
            updatedAt: conflict.localSnapshot?.updatedAt,
            isDark: isDark,
            theme: theme,
          ),
          const SizedBox(height: 4),
          _VersionRow(
            label: l10n.syncConflictRemoteVersion,
            version:
                conflict.remoteSnapshot?.version ?? conflict.currentVersion,
            updatedAt: conflict.remoteSnapshot?.updatedAt ?? conflict.updatedAt,
            isDark: isDark,
            theme: theme,
          ),
          const SizedBox(height: 12),
          if (resolving)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onKeepRemote,
                    child: Text(l10n.syncConflictKeepRemote),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onKeepLocal,
                    child: Text(l10n.syncConflictKeepLocal),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$d/$mo $h:$mi';
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind});

  final SyncConflictOperationKind kind;

  @override
  Widget build(BuildContext context) {
    final label = kind == SyncConflictOperationKind.delete
        ? context.l10n.syncConflictKindDelete
        : context.l10n.syncConflictKindUpsert;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.version,
    required this.updatedAt,
    required this.isDark,
    required this.theme,
  });

  final String label;
  final int? version;
  final DateTime? updatedAt;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: secondary),
        ),
        const Spacer(),
        if (version != null)
          Text(
            'v$version',
            style: theme.textTheme.labelSmall?.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (updatedAt != null) ...[
          const SizedBox(width: 8),
          Text(
            _fmt(updatedAt!),
            style: theme.textTheme.labelSmall?.copyWith(color: secondary),
          ),
        ],
      ],
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$d/$mo $h:$mi';
  }
}
