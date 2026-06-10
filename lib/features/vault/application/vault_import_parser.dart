import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../domain/vault_item.dart';
import 'vault_duplicate_detector.dart';
import 'vault_import_models.dart';

class VaultImportParser {
  const VaultImportParser({Uuid? uuid, VaultDuplicateDetector? duplicates})
    : _uuid = uuid ?? const Uuid(),
      _duplicates = duplicates ?? const VaultDuplicateDetector();

  final Uuid _uuid;
  final VaultDuplicateDetector _duplicates;

  VaultImportPreview parse({
    required String fileName,
    required String content,
    required List<VaultItem> existingItems,
  }) {
    final trimmed = content.trimLeft();
    final source = _detectSource(fileName, trimmed);
    final parsed =
        source == VaultImportSource.json ||
            source == VaultImportSource.bitwardenJson
        ? _parseJson(trimmed, source)
        : _parseCsv(content, source);

    final candidates = <VaultImportCandidate>[];
    final knownItems = List<VaultItem>.of(existingItems);

    for (final candidate in parsed.candidates) {
      final match = _duplicates.findDuplicate(candidate.item, knownItems);
      if (match == null) {
        candidates.add(candidate);
        knownItems.add(candidate.item);
      } else {
        candidates.add(
          candidate.copyWith(isDuplicate: true, duplicateReason: match.reason),
        );
      }
    }

    return VaultImportPreview(
      source: parsed.source,
      candidates: candidates,
      rejected: parsed.rejected,
    );
  }

  VaultImportSource _detectSource(String fileName, String content) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.json') ||
        content.startsWith('{') ||
        content.startsWith('[')) {
      return lower.contains('bitwarden')
          ? VaultImportSource.bitwardenJson
          : VaultImportSource.json;
    }
    if (lower.contains('notion')) return VaultImportSource.notionCsv;
    if (lower.contains('chrome')) return VaultImportSource.chromeCsv;
    if (lower.contains('bitwarden')) return VaultImportSource.bitwardenCsv;
    if (lower.contains('1password') || lower.contains('onepassword')) {
      return VaultImportSource.onePasswordCsv;
    }
    if (lower.contains('lastpass')) return VaultImportSource.lastPassCsv;
    if (lower.contains('keepass')) return VaultImportSource.keepassCsv;
    return VaultImportSource.genericCsv;
  }

  VaultImportPreview _parseCsv(String content, VaultImportSource source) {
    final rows = _readCsvRows(content);
    if (rows.isEmpty) {
      return VaultImportPreview(
        source: source,
        candidates: const [],
        rejected: const [
          VaultImportIssue(
            message: 'El archivo CSV esta vacio.',
            severity: VaultImportIssueSeverity.error,
          ),
        ],
      );
    }

    final header = rows.first.map(_normalizeHeader).toList(growable: false);
    final candidates = <VaultImportCandidate>[];
    final rejected = <VaultImportIssue>[];

    for (var index = 1; index < rows.length; index++) {
      final rawRow = rows[index];
      if (rawRow.every((cell) => cell.trim().isEmpty)) continue;
      final row = <String, String>{};
      for (var col = 0; col < header.length; col++) {
        row[header[col]] = col < rawRow.length ? rawRow[col].trim() : '';
      }
      final candidate = _candidateFromMap(
        row: row,
        source: source,
        rowNumber: index + 1,
      );
      if (candidate == null) {
        rejected.add(
          VaultImportIssue(
            row: index + 1,
            severity: VaultImportIssueSeverity.error,
            message: 'La fila no tiene titulo ni password reconocible.',
          ),
        );
      } else {
        candidates.add(candidate);
      }
    }

    return VaultImportPreview(
      source: source,
      candidates: candidates,
      rejected: rejected,
    );
  }

  VaultImportPreview _parseJson(String content, VaultImportSource source) {
    final candidates = <VaultImportCandidate>[];
    final rejected = <VaultImportIssue>[];
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (error) {
      return VaultImportPreview(
        source: source,
        candidates: const [],
        rejected: [
          VaultImportIssue(
            severity: VaultImportIssueSeverity.error,
            message: 'No pudimos leer el JSON: $error',
          ),
        ],
      );
    }

    final records = _extractJsonRecords(decoded);
    for (var index = 0; index < records.length; index++) {
      final candidate = _candidateFromMap(
        row: records[index].map(
          (key, value) => MapEntry(_normalizeHeader(key), '$value'.trim()),
        ),
        source: source,
        rowNumber: index + 1,
      );
      if (candidate == null) {
        rejected.add(
          VaultImportIssue(
            row: index + 1,
            severity: VaultImportIssueSeverity.error,
            message: 'El registro JSON no tiene credenciales reconocibles.',
          ),
        );
      } else {
        candidates.add(candidate);
      }
    }

    return VaultImportPreview(
      source: source,
      candidates: candidates,
      rejected: rejected,
    );
  }

  List<Map<String, Object?>> _extractJsonRecords(Object? decoded) {
    if (decoded is List) {
      return decoded.whereType<Map>().map(_mapFromDynamic).toList();
    }
    if (decoded is Map) {
      final map = _mapFromDynamic(decoded);
      final items = map['items'] ?? map['entries'] ?? map['logins'];
      if (items is List) {
        return items.whereType<Map>().map((entry) {
          final result = _mapFromDynamic(entry);
          final login = result['login'];
          if (login is Map) {
            final loginMap = _mapFromDynamic(login);
            result.addAll(loginMap);
            final uris = loginMap['uris'];
            if (uris is List && uris.isNotEmpty) {
              final firstUri = uris.first;
              if (firstUri is Map && firstUri['uri'] != null) {
                result['uri'] = firstUri['uri'];
              }
            }
          }
          return result;
        }).toList();
      }
      return [map];
    }
    return const [];
  }

  Map<String, Object?> _mapFromDynamic(Map<dynamic, dynamic> map) {
    return map.map((key, value) => MapEntry('$key', value));
  }

  VaultImportCandidate? _candidateFromMap({
    required Map<String, String> row,
    required VaultImportSource source,
    required int rowNumber,
  }) {
    final title = _first(row, const [
      'title',
      'name',
      'nombre',
      'service',
      'servicio',
      'site',
      'sitio',
      'login_uri',
      'url',
    ]);
    final secret = _first(row, const [
      'password',
      'secret',
      'contrasena',
      'contraseña',
      'pass',
      'clave',
    ]);
    final username = _first(row, const [
      'username',
      'user',
      'email',
      'login',
      'usuario',
      'usuario_o_email',
      'user_name',
    ]);
    final website = _first(row, const [
      'url',
      'website',
      'uri',
      'login_uri',
      'loginurl',
      'sitio',
      'web',
    ]);
    final notes = _first(row, const ['notes', 'note', 'notas', 'nota']);
    final categoryValue = _first(row, const [
      'category',
      'folder',
      'collection',
      'categoria',
      'categoría',
      'type',
    ]);

    if (title.isEmpty && secret.isEmpty) return null;

    final issues = <VaultImportIssue>[];
    if (secret.isEmpty) {
      issues.add(
        const VaultImportIssue(
          severity: VaultImportIssueSeverity.error,
          message: 'Falta el password o secreto.',
        ),
      );
    }
    if (title.isEmpty) {
      issues.add(
        const VaultImportIssue(
          severity: VaultImportIssueSeverity.warning,
          message: 'No habia titulo; Vaulta uso el sitio o usuario.',
        ),
      );
    }

    final fallbackTitle = website.isNotEmpty
        ? website
        : (username.isNotEmpty ? username : 'Entrada importada');
    final now = DateTime.now();
    final item = VaultItem(
      id: _uuid.v4(),
      title: title.isEmpty ? fallbackTitle : title,
      username: username,
      secret: secret,
      category: _categoryFromImport(categoryValue),
      strengthScore: estimatePasswordStrength(secret),
      lastUpdatedLabel: formatVaultUpdatedLabel(now),
      website: website.isEmpty ? null : website,
      notes: notes.isEmpty ? null : notes,
      updatedAt: now,
    );

    return VaultImportCandidate(
      item: item,
      source: source,
      row: rowNumber,
      issues: issues,
    );
  }

  VaultCategory _categoryFromImport(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized.contains('work') ||
        normalized.contains('trabajo') ||
        normalized.contains('business')) {
      return VaultCategory.work;
    }
    if (normalized.contains('bank') ||
        normalized.contains('finance') ||
        normalized.contains('finanza') ||
        normalized.contains('pago')) {
      return VaultCategory.finance;
    }
    if (normalized.contains('server') ||
        normalized.contains('infra') ||
        normalized.contains('dev') ||
        normalized.contains('ssh')) {
      return VaultCategory.infrastructure;
    }
    return VaultCategory.personal;
  }

  String _first(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final value = row[_normalizeHeader(key)]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  String _normalizeHeader(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll('-', '_');
  }

  List<List<String>> _readCsvRows(String input) {
    final delimiter = _detectCsvDelimiter(input);
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    var index = 0;

    while (index < input.length) {
      final char = input[index];
      if (char == '"') {
        final nextIsQuote = index + 1 < input.length && input[index + 1] == '"';
        if (inQuotes && nextIsQuote) {
          current.write('"');
          index += 2;
          continue;
        }
        inQuotes = !inQuotes;
      } else if (char == delimiter && !inQuotes) {
        currentRow.add(current.toString());
        current.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }
        currentRow.add(current.toString());
        current.clear();
        rows.add(List<String>.from(currentRow));
        currentRow.clear();
      } else {
        current.write(char);
      }
      index++;
    }

    if (current.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(current.toString());
      rows.add(List<String>.from(currentRow));
    }
    return rows;
  }

  String _detectCsvDelimiter(String input) {
    final lines = input.split(RegExp(r'\r?\n'));
    final firstLine = lines.isEmpty ? '' : lines.first;
    final commaCount = ','.allMatches(firstLine).length;
    final semicolonCount = ';'.allMatches(firstLine).length;
    return semicolonCount > commaCount ? ';' : ',';
  }
}
