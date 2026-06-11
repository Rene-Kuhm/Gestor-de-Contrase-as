import 'package:flutter/material.dart';

import '../../../app/design_system/app_components.dart';
import '../../../app/design_system/app_panel.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/sync/sync_conflict.dart';
import '../../../core/sync/sync_conflict_resolver.dart';

/// Shows the modal bottom sheet that lists pending [SyncConflictRecord]s
/// from [resolver] and lets the user pick `keep local` or
/// `keep remote` for each one. Resolves to `void`; the sheet is
/// dismissed by the user or by completing the empty state.
Future<void> showSyncConflictsSheet({
  required BuildContext context,
  required SyncConflictResolver resolver,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.syncConflictResolveError)),
        );
      }
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
    final l10n = context.l10n;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? AppColors.borderDark
                : AppColors.borderLight,
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: const Icon(
                        Icons.sync_problem_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.syncConflictsTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  l10n.syncConflictsSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Divider(color: theme.colorScheme.outlineVariant, height: 1),
              Expanded(
                child: FutureBuilder<List<SyncConflictRecord>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _SheetErrorState(
                        message: l10n.syncConflictsLoadError,
                        retryLabel: l10n.retry,
                        onRetry: () => setState(_reload),
                      );
                    }

                    final conflicts = snapshot.data ?? [];

                    if (conflicts.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.18,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusXl,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                l10n.syncConflictsEmpty,
                                style: theme.textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      itemCount: conflicts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final conflict = conflicts[index];
                        return _ConflictTile(
                          conflict: conflict,
                          resolving: _resolving.contains(conflict.id),
                          onKeepLocal: () => _resolve(
                            conflict.id,
                            SyncConflictResolution.keepLocal,
                          ),
                          onKeepRemote: () => _resolve(
                            conflict.id,
                            SyncConflictResolution.keepRemote,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetErrorState extends StatelessWidget {
  const _SheetErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppBanner(
          message: message,
          tone: AppBannerTone.danger,
          icon: Icons.error_outline_rounded,
          action: FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(retryLabel),
          ),
        ),
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
    final l10n = context.l10n;

    return AppPanel(
      tint: AppGlassTint.regular,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppPill(
                label: conflict.kind == SyncConflictOperationKind.delete
                    ? l10n.syncConflictKindDelete
                    : l10n.syncConflictKindUpsert,
                tint: AppPillTint.warning,
                compact: true,
              ),
              const Spacer(),
              Text(
                _formatDate(conflict.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _VersionRow(
            label: l10n.syncConflictLocalVersion,
            version: conflict.localSnapshot?.version,
            updatedAt: conflict.localSnapshot?.updatedAt,
          ),
          const SizedBox(height: AppSpacing.xs),
          _VersionRow(
            label: l10n.syncConflictRemoteVersion,
            version:
                conflict.remoteSnapshot?.version ?? conflict.currentVersion,
            updatedAt: conflict.remoteSnapshot?.updatedAt ?? conflict.updatedAt,
          ),
          const SizedBox(height: AppSpacing.md),
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
                const SizedBox(width: AppSpacing.sm),
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

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.version,
    required this.updatedAt,
  });

  final String label;
  final int? version;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (version != null)
          Text(
            'v$version',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        if (updatedAt != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            _fmt(updatedAt!),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
