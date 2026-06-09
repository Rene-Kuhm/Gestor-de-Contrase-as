class RemoteVaultBlobChange {
  const RemoteVaultBlobChange({
    required this.opCursor,
    required this.recordId,
    required this.version,
    required this.keyVersion,
    required this.updatedAt,
    this.ciphertext,
    this.nonce,
    this.gcmTag,
    this.deletedAt,
  });

  final int opCursor;
  final String recordId;
  final int version;
  final int keyVersion;
  final String? ciphertext;
  final String? nonce;
  final String? gcmTag;
  final DateTime? deletedAt;
  final DateTime updatedAt;

  bool get isTombstone => deletedAt != null;

  factory RemoteVaultBlobChange.fromSupabaseRows({
    required Map<String, dynamic> opRow,
    required Map<String, dynamic> blobRow,
  }) {
    final opCursor = _readRequiredInt(opRow, 'id');
    final recordId = _readRequiredString(blobRow, 'record_id');

    final deletedRaw = blobRow['deleted_at'];
    final deletedAt = deletedRaw == null
        ? null
        : DateTime.parse(deletedRaw as String).toUtc();

    final updatedRaw = blobRow['updated_at'];
    final updatedAt = updatedRaw == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.parse(updatedRaw as String).toUtc();

    return RemoteVaultBlobChange(
      opCursor: opCursor,
      recordId: recordId,
      version: _readRequiredInt(blobRow, 'version'),
      keyVersion: _readRequiredInt(blobRow, 'key_version'),
      ciphertext: deletedAt == null ? blobRow['ciphertext'] as String? : null,
      nonce: deletedAt == null ? blobRow['nonce'] as String? : null,
      gcmTag: deletedAt == null ? _readNullableGcmTag(blobRow) : null,
      deletedAt: deletedAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'opCursor': opCursor,
      'recordId': recordId,
      'version': version,
      'keyVersion': keyVersion,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'gcmTag': gcmTag,
      'deletedAt': deletedAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RemoteVaultBlobChange.fromJson(Map<String, dynamic> json) {
    return RemoteVaultBlobChange(
      opCursor: json['opCursor'] as int,
      recordId: json['recordId'] as String,
      version: json['version'] as int,
      keyVersion: json['keyVersion'] as int,
      ciphertext: json['ciphertext'] as String?,
      nonce: json['nonce'] as String?,
      gcmTag: _readNullableGcmTag(json),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  static int _readRequiredInt(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw FormatException('Missing numeric field: $key');
  }

  static String _readRequiredString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('Missing string field: $key');
  }

  static String? _readNullableGcmTag(Map<String, dynamic> row) {
    final value = row['gcmTag'] ?? row['gcm_tag'] ?? row['aad'];
    return value is String && value.isNotEmpty ? value : null;
  }
}

class RemoteVaultBlobSnapshot {
  const RemoteVaultBlobSnapshot({
    required this.recordId,
    required this.version,
    required this.keyVersion,
    required this.updatedAt,
    this.ciphertext,
    this.nonce,
    this.gcmTag,
    this.deletedAt,
  });

  final String recordId;
  final int version;
  final int keyVersion;
  final String? ciphertext;
  final String? nonce;
  final String? gcmTag;
  final DateTime? deletedAt;
  final DateTime updatedAt;

  bool get isTombstone => deletedAt != null;

  factory RemoteVaultBlobSnapshot.fromChange(RemoteVaultBlobChange change) {
    return RemoteVaultBlobSnapshot(
      recordId: change.recordId,
      version: change.version,
      keyVersion: change.keyVersion,
      ciphertext: change.ciphertext,
      nonce: change.nonce,
      gcmTag: change.gcmTag,
      deletedAt: change.deletedAt,
      updatedAt: change.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recordId': recordId,
      'version': version,
      'keyVersion': keyVersion,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'gcmTag': gcmTag,
      'deletedAt': deletedAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RemoteVaultBlobSnapshot.fromJson(Map<String, dynamic> json) {
    return RemoteVaultBlobSnapshot(
      recordId: json['recordId'] as String,
      version: json['version'] as int,
      keyVersion: json['keyVersion'] as int,
      ciphertext: json['ciphertext'] as String?,
      nonce: json['nonce'] as String?,
      gcmTag: RemoteVaultBlobChange._readNullableGcmTag(json),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }
}
