import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/design_system/app_components.dart';
import '../../../app/design_system/app_panel.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/security/vault_repository.dart';
import '../application/vault_duplicate_detector.dart';
import '../application/vault_import_models.dart';
import '../application/vault_import_parser.dart';
import '../domain/vault_item.dart';

class VaultImportScreen extends StatefulWidget {
  const VaultImportScreen({
    super.key,
    required this.repository,
    required this.existingItems,
    VaultImportParser? parser,
    this.initialPreview,
  }) : parser = parser ?? const _DefaultVaultImportParser._();

  final VaultRepository repository;
  final List<VaultItem> existingItems;
  final VaultImportParser parser;
  final VaultImportPreview? initialPreview;

  @override
  State<VaultImportScreen> createState() => _VaultImportScreenState();
}

class _VaultImportScreenState extends State<VaultImportScreen> {
  static const _duplicates = VaultDuplicateDetector();

  VaultImportPreview? _preview;
  String? _fileName;
  String? _error;
  bool _isPicking = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _preview = widget.initialPreview;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Importar credenciales')),
      body: AppHeroBackground(
        intensity: 0.55,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionHeader(
                      eyebrow: 'IMPORTACION LOCAL',
                      title: 'Trae tus passwords a Vaulta',
                      subtitle:
                          'Carga CSV o JSON desde Notion, Chrome, Bitwarden, 1Password, LastPass, KeePass, Excel o Google Sheets. Vaulta procesa el archivo localmente y cifra cada entrada al guardar.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: const [
                        _ImportChip(label: 'CSV generico'),
                        _ImportChip(label: 'JSON'),
                        _ImportChip(label: 'Notion'),
                        _ImportChip(label: 'Chrome'),
                        _ImportChip(label: 'Bitwarden'),
                        _ImportChip(label: '1Password'),
                        _ImportChip(label: 'LastPass'),
                        _ImportChip(label: 'KeePass'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _isPicking ? null : _pickFile,
                      icon: _isPicking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_rounded),
                      label: Text(
                        _isPicking ? 'Leyendo archivo...' : 'Elegir archivo',
                      ),
                    ),
                    if (_fileName != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _fileName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppBanner(
                        message: _error!,
                        icon: Icons.error_outline_rounded,
                        tone: AppBannerTone.danger,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_preview != null) _ImportPreviewPanel(preview: _preview!),
              if (_preview != null) const SizedBox(height: AppSpacing.lg),
              if (_preview != null)
                FilledButton.icon(
                  onPressed: _preview!.importableCount == 0 || _isImporting
                      ? null
                      : _confirmImport,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_rounded),
                  label: Text(
                    _isImporting
                        ? 'Importando...'
                        : 'Importar ${_preview!.importableCount} entradas',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isPicking = true;
      _error = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _error = 'No pudimos leer el archivo seleccionado.';
        });
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final preview = widget.parser.parse(
        fileName: file.name,
        content: content,
        existingItems: widget.existingItems,
      );

      setState(() {
        _fileName = file.name;
        _preview = preview;
      });
    } catch (error) {
      setState(() {
        _error = 'No pudimos preparar la importacion: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _confirmImport() async {
    final preview = _preview;
    if (preview == null) return;

    setState(() {
      _isImporting = true;
      _error = null;
    });
    var imported = 0;
    var skippedDuplicates = 0;
    try {
      final existingItems = await widget.repository.fetchItems();
      final knownItems = List<VaultItem>.of(existingItems);
      for (final candidate in preview.candidates) {
        if (!candidate.canImport) continue;
        final duplicate = _duplicates.findDuplicate(candidate.item, knownItems);
        if (duplicate != null) {
          skippedDuplicates++;
          continue;
        }
        await widget.repository.saveItem(candidate.item);
        knownItems.add(candidate.item);
        imported++;
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        VaultImportResult(
          imported: imported,
          skippedDuplicates: skippedDuplicates,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'La importacion se interrumpio: $error';
        _isImporting = false;
      });
    }
  }
}

class _DefaultVaultImportParser extends VaultImportParser {
  const _DefaultVaultImportParser._();
}

class _ImportChip extends StatelessWidget {
  const _ImportChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      avatar: const Icon(Icons.check_rounded, size: 16),
    );
  }
}

class _ImportPreviewPanel extends StatelessWidget {
  const _ImportPreviewPanel({required this.preview});

  final VaultImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidates = preview.candidates.take(25).toList(growable: false);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            eyebrow: preview.source.label.toUpperCase(),
            title: 'Vista previa',
            subtitle:
                '${preview.importableCount} listas para importar, ${preview.duplicateCount} duplicadas, ${preview.rejectedCount} rechazadas.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (preview.rejected.isNotEmpty)
            AppBanner(
              message:
                  'Algunas filas no se pueden importar porque no tienen campos reconocibles.',
              icon: Icons.report_problem_rounded,
              tone: AppBannerTone.warning,
            ),
          if (preview.rejected.isNotEmpty)
            const SizedBox(height: AppSpacing.md),
          for (final candidate in candidates) ...[
            _ImportCandidateTile(candidate: candidate),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (preview.candidates.length > candidates.length)
            Text(
              'Mostrando 25 de ${preview.candidates.length} entradas detectadas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _ImportCandidateTile extends StatelessWidget {
  const _ImportCandidateTile({required this.candidate});

  final VaultImportCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = candidate.item;
    final statusColor = candidate.canImport
        ? AppColors.success
        : (candidate.isDuplicate ? AppColors.warning : AppColors.danger);
    final statusLabel = candidate.canImport
        ? 'Lista'
        : (candidate.isDuplicate ? 'Duplicada' : 'Revisar');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.accentColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(item.icon, color: item.accentColor, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (item.username.isNotEmpty) item.username,
                    if (item.website != null) item.website!,
                    item.category.label,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (candidate.issues.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    candidate.issues.map((issue) => issue.message).join(' '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
                if (candidate.duplicateReason != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    candidate.duplicateReason!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
