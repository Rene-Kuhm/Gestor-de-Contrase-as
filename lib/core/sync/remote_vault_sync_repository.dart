import 'remote_vault_blob_change.dart';

abstract interface class RemoteVaultSyncRepository {
  Future<String?> readCurrentUserId();

  Future<List<RemoteVaultBlobChange>> fetchChangesSince({
    required int afterOpId,
    int limit,
  });

  Future<RemoteVaultPushResult> pushUpsertBlob({
    required String deviceId,
    required String idempotencyKey,
    required String recordId,
    required int? expectedVersion,
    required String ciphertext,
    required String nonce,
    required String? aad,
    required int keyVersion,
  });

  Future<RemoteVaultPushResult> pushDeleteBlob({
    required String deviceId,
    required String idempotencyKey,
    required String recordId,
    required int expectedVersion,
  });
}

enum RemoteVaultPushResultCode {
  applied,
  idempotentReplay,
  casConflict,
  idempotencyMismatch,
  unknown,
}

class RemoteVaultPushResult {
  const RemoteVaultPushResult({
    required this.code,
    required this.applied,
    required this.idempotentReplay,
    required this.conflict,
    this.message,
    this.recordId,
    this.currentVersion,
    this.appliedVersion,
    this.deletedAt,
  });

  final RemoteVaultPushResultCode code;
  final bool applied;
  final bool idempotentReplay;
  final bool conflict;
  final String? message;
  final String? recordId;
  final int? currentVersion;
  final int? appliedVersion;
  final DateTime? deletedAt;

  bool get isSuccess => applied || idempotentReplay;

  factory RemoteVaultPushResult.fromRpcRow(Map<String, dynamic> row) {
    final rawCode = row['result_code'] as String?;
    return RemoteVaultPushResult(
      code: _parseCode(rawCode),
      applied: row['applied'] as bool? ?? false,
      idempotentReplay: row['idempotent_replay'] as bool? ?? false,
      conflict: row['conflict'] as bool? ?? false,
      message: row['message'] as String?,
      recordId: row['record_id'] as String?,
      currentVersion: _readNullableInt(row['current_version']),
      appliedVersion: _readNullableInt(row['applied_version']),
      deletedAt: _readNullableDateTime(row['deleted_at']),
    );
  }

  static RemoteVaultPushResultCode _parseCode(String? value) {
    return switch (value) {
      'applied' => RemoteVaultPushResultCode.applied,
      'idempotent_replay' => RemoteVaultPushResultCode.idempotentReplay,
      'cas_conflict' => RemoteVaultPushResultCode.casConflict,
      'idempotency_mismatch' => RemoteVaultPushResultCode.idempotencyMismatch,
      _ => RemoteVaultPushResultCode.unknown,
    };
  }

  static int? _readNullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static DateTime? _readNullableDateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.parse(value).toUtc();
  }
}
