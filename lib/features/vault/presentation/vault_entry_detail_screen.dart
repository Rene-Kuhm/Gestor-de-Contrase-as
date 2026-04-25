import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_spacing.dart';
import '../domain/vault_item.dart';

class VaultEntryDetailScreen extends StatefulWidget {
  const VaultEntryDetailScreen({
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
  });

  final VaultItem item;
  final Future<bool> Function()? onEdit;
  final Future<void> Function()? onDelete;

  @override
  State<VaultEntryDetailScreen> createState() => _VaultEntryDetailScreenState();
}

class _VaultEntryDetailScreenState extends State<VaultEntryDetailScreen> {
  static const _clipboardClearDelay = Duration(seconds: 30);

  bool _obscureSecret = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.entryDetailTitle),
        actions: [
          IconButton(
            onPressed: widget.onEdit == null ? null : _runEdit,
            icon: const Icon(Icons.edit_rounded),
            tooltip: l10n.entryEditTooltip,
          ),
          IconButton(
            onPressed: widget.onDelete == null ? null : _confirmDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: l10n.entryDeleteTooltip,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: item.accentColor.withValues(
                          alpha: 0.14,
                        ),
                        child: Icon(item.icon, color: item.accentColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.category.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: item.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _MetaRow(
                    label: l10n.entryUsernameLabel,
                    value: item.username,
                  ),
                  if (item.website != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _MetaRow(
                      label: l10n.entryWebsiteLabel,
                      value: item.website!,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _MetaRow(
                    label: l10n.entryStrengthLabel,
                    value: '${item.strengthScore}%',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MetaRow(
                    label: l10n.entryUpdatedLabel,
                    value: item.lastUpdatedLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.entrySecretTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _obscureSecret = !_obscureSecret);
                        },
                        icon: Icon(
                          _obscureSecret
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                        label: Text(
                          _obscureSecret
                              ? l10n.entryShowSecret
                              : l10n.entryHideSecret,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SelectableText(
                      _obscureSecret ? _mask(item.secret) : item.secret,
                      style: theme.textTheme.titleMedium?.copyWith(
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => _copySecret(item.secret),
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(context.l10n.copySecret),
                  ),
                ],
              ),
            ),
            if (item.notes != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.entryNotesTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(item.notes!, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _mask(String secret) {
    if (secret.length <= 4) {
      return List.filled(secret.length, '*').join();
    }
    final hidden = List.filled(secret.length - 4, '*').join();
    return '$hidden${secret.substring(secret.length - 4)}';
  }

  Future<void> _runEdit() async {
    final changed = await widget.onEdit?.call() ?? false;
    if (changed && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _copySecret(String secret) async {
    await Clipboard.setData(ClipboardData(text: secret));
    unawaited(_clearClipboardIfUnchanged(secret));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.secretCopiedLocally)));
  }

  Future<void> _clearClipboardIfUnchanged(String secret) async {
    await Future<void>.delayed(_clipboardClearDelay);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != secret) {
      return;
    }

    await Clipboard.setData(const ClipboardData(text: ''));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.clipboardCleared)));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.entryDeleteDialogTitle),
          content: Text(context.l10n.entryDeleteDialogBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.entryDeleteConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await widget.onDelete?.call();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
