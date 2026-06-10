import '../domain/vault_item.dart';

enum VaultImportSource {
  genericCsv('CSV generico'),
  notionCsv('Notion CSV'),
  chromeCsv('Chrome CSV'),
  bitwardenCsv('Bitwarden CSV'),
  bitwardenJson('Bitwarden JSON'),
  onePasswordCsv('1Password CSV'),
  lastPassCsv('LastPass CSV'),
  keepassCsv('KeePass CSV'),
  json('JSON');

  const VaultImportSource(this.label);

  final String label;
}

enum VaultImportIssueSeverity { warning, error }

class VaultImportIssue {
  const VaultImportIssue({
    required this.message,
    required this.severity,
    this.row,
  });

  final String message;
  final VaultImportIssueSeverity severity;
  final int? row;
}

class VaultImportCandidate {
  const VaultImportCandidate({
    required this.item,
    required this.source,
    required this.row,
    this.issues = const [],
    this.isDuplicate = false,
    this.duplicateReason,
  });

  final VaultItem item;
  final VaultImportSource source;
  final int row;
  final List<VaultImportIssue> issues;
  final bool isDuplicate;
  final String? duplicateReason;

  bool get canImport =>
      !isDuplicate &&
      issues.every((issue) => issue.severity != VaultImportIssueSeverity.error);

  VaultImportCandidate copyWith({
    VaultItem? item,
    VaultImportSource? source,
    int? row,
    List<VaultImportIssue>? issues,
    bool? isDuplicate,
    String? duplicateReason,
  }) {
    return VaultImportCandidate(
      item: item ?? this.item,
      source: source ?? this.source,
      row: row ?? this.row,
      issues: issues ?? this.issues,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateReason: duplicateReason ?? this.duplicateReason,
    );
  }
}

class VaultImportPreview {
  const VaultImportPreview({
    required this.source,
    required this.candidates,
    required this.rejected,
  });

  final VaultImportSource source;
  final List<VaultImportCandidate> candidates;
  final List<VaultImportIssue> rejected;

  int get importableCount =>
      candidates.where((candidate) => candidate.canImport).length;

  int get duplicateCount =>
      candidates.where((candidate) => candidate.isDuplicate).length;

  int get rejectedCount => rejected.length;
}

class VaultImportResult {
  const VaultImportResult({
    required this.imported,
    required this.skippedDuplicates,
  });

  final int imported;
  final int skippedDuplicates;
}
