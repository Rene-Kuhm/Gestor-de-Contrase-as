import 'dart:convert';
import 'dart:io';

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

    final preview = _preview;
    final canImport = preview != null && preview.importableCount > 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          preview == null
              ? 'Importar credenciales'
              : 'Importar (${preview.importableCount})',
        ),
      ),
      body: AppHeroBackground(
        intensity: 0.55,
        child: SafeArea(
          bottom: canImport,
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
              if (preview != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _ImportPreviewPanel(preview: preview),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: canImport
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Material(
                color: Colors.transparent,
                child: FilledButton.icon(
                  onPressed: _isImporting ? null : _confirmImport,
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
                        : 'Importar ${preview.importableCount} entradas',
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isPicking = true;
      _error = null;
    });

    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'json'],
        withData: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPicking = false;
        _error = 'No pudimos abrir el selector de archivos: $error';
      });
      return;
    }

    if (!mounted) return;

    if (result == null || result.files.isEmpty) {
      setState(() {
        _isPicking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccion cancelada.')),
      );
      return;
    }

    final file = result.files.single;
    final bytes = await _readPickedFileBytes(file);
    if (!mounted) return;

    if (bytes.isEmpty) {
      setState(() {
        _isPicking = false;
        _error = 'El archivo seleccionado esta vacio o no se pudo leer. '
            'Proba con otro archivo o reinicia la app.';
      });
      return;
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    final preview = widget.parser.parse(
      fileName: file.name,
      content: content,
      existingItems: widget.existingItems,
    );
    debugPrint(
      '[Vaulta/Import] preview file=${file.name} bytes=${bytes.length} '
      'source=${preview.source.name} candidates=${preview.candidates.length} '
      'importable=${preview.importableCount} duplicates=${preview.duplicateCount} '
      'rejected=${preview.rejectedCount}',
    );

    setState(() {
      _fileName = file.name;
      _preview = preview;
      _isPicking = false;
    });

    if (preview.importableCount == 0 && preview.rejected.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se detectaron entradas validas. '
            'Revisa que el archivo tenga titulo y password reconocibles.',
          ),
        ),
      );
    }
  }

  Future<List<int>> _readPickedFileBytes(PlatformFile file) async {
    final inMemoryBytes = file.bytes;
    if (inMemoryBytes != null && inMemoryBytes.isNotEmpty) {
      return inMemoryBytes;
    }

    final path = file.path;
    if (path != null && path.isNotEmpty) {
      try {
        return await File(path).readAsBytes();
      } catch (error) {
        debugPrint('[Vaulta/Import] readAsBytes failed: $error');
      }
    }

    return const [];
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
      debugPrint(
        '[Vaulta/Import] confirm candidates=${preview.candidates.length} '
        'existing=${existingItems.length}',
      );
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

      if (imported == 0) {
        setState(() {
          _isImporting = false;
          _error = skippedDuplicates > 0
              ? 'No se importaron entradas nuevas: todas ya existen en Vaulta.'
              : 'No se importaron entradas. Revisa que el archivo tenga titulo, usuario y password reconocibles.';
        });
        debugPrint(
          '[Vaulta/Import] finished imported=0 skippedDuplicates=$skippedDuplicates',
        );
        return;
      }
      debugPrint(
        '[Vaulta/Import] finished imported=$imported '
        'skippedDuplicates=$skippedDuplicates',
      );
      Navigator.of(context).pop(
        VaultImportResult(
          imported: imported,
          skippedDuplicates: skippedDuplicates,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final errorText = error.toString();
      final isSessionLocked =
          errorText.contains('Vault encryption key unavailable') ||
          errorText.contains('Unlock with the master password');
      setState(() {
        if (isSessionLocked) {
          _error =
              'Tu sesion de Vaulta esta bloqueada. Desbloquea con la master '
              'password para poder importar.';
        } else {
          _error = 'La importacion se interrumpio: $error';
        }
        _isImporting = false;
      });
      debugPrint(
        '[Vaulta/Import] aborted error=$error isSessionLocked=$isSessionLocked',
      );
      if (isSessionLocked && mounted) {
        // Pop back to the dashboard so the security gate can take over
        // and prompt the user to unlock with the master password. The
        // selected preview is discarded on purpose: the user's
        // decision to import has to be retaken after unlock, with a
        // fresh session in memory.
        final navigator = Navigator.of(context);
        navigator.pop<VaultImportResult>(null);
      }
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
