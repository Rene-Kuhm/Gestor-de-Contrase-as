import 'dart:convert';

import '../security/secure_storage_service.dart';
import 'local_vault_mutation.dart';
import 'remote_vault_blob_change.dart';

class LocalRemoteVaultStore {
  LocalRemoteVaultStore({required SecureStorageService storage})
    : _storage = storage;

  static const _cursorPrefix = 'vault_sync_pull_cursor_v1';
  static const _lastPullPrefix = 'vault_sync_pull_last_at_v1';
  static const _blobPrefix = 'vault_sync_remote_blobs_v1';
  static const _pushQueuePrefix = 'vault_sync_push_queue_v1';

  final SecureStorageService _storage;

  Future<int> readCursor({
    required String userId,
    required String deviceId,
  }) async {
    final raw = await _storage.read(_cursorKey(userId: userId, deviceId: deviceId));
    if (raw == null || raw.isEmpty) {
      return 0;
    }

    final parsed = int.tryParse(raw);
    return parsed ?? 0;
  }

  Future<void> saveCursor({
    required String userId,
    required String deviceId,
    required int cursor,
  }) {
    return _storage.save(
      _cursorKey(userId: userId, deviceId: deviceId),
      cursor.toString(),
    );
  }

  Future<DateTime?> readLastPullAt({
    required String userId,
    required String deviceId,
  }) async {
    final raw = await _storage.read(
      _lastPullKey(userId: userId, deviceId: deviceId),
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> saveLastPullAt({
    required String userId,
    required String deviceId,
    required DateTime lastPullAt,
  }) {
    return _storage.save(
      _lastPullKey(userId: userId, deviceId: deviceId),
      lastPullAt.toUtc().toIso8601String(),
    );
  }

  Future<Map<String, RemoteVaultBlobSnapshot>> readSnapshots({
    required String userId,
  }) async {
    final raw = await _storage.read(_blobKey(userId: userId));
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final snapshots = <String, RemoteVaultBlobSnapshot>{};
    for (final entry in payload.entries) {
      snapshots[entry.key] = RemoteVaultBlobSnapshot.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }
    return snapshots;
  }

  Future<void> applyChanges({
    required String userId,
    required String deviceId,
    required List<RemoteVaultBlobChange> changes,
    required int newCursor,
  }) async {
    final snapshots = await readSnapshots(userId: userId);
    for (final change in changes) {
      final existing = snapshots[change.recordId];
      if (!_shouldApply(existing: existing, incoming: change)) {
        continue;
      }

      snapshots[change.recordId] = RemoteVaultBlobSnapshot.fromChange(change);
    }

    final encoded = <String, dynamic>{
      for (final entry in snapshots.entries) entry.key: entry.value.toJson(),
    };
    await _storage.save(_blobKey(userId: userId), jsonEncode(encoded));
    await saveCursor(userId: userId, deviceId: deviceId, cursor: newCursor);
  }

  Future<void> saveSnapshot({
    required String userId,
    required RemoteVaultBlobSnapshot snapshot,
  }) async {
    final snapshots = await readSnapshots(userId: userId);
    snapshots[snapshot.recordId] = snapshot;
    final encoded = <String, dynamic>{
      for (final entry in snapshots.entries) entry.key: entry.value.toJson(),
    };
    await _storage.save(_blobKey(userId: userId), jsonEncode(encoded));
  }

  Future<RemoteVaultBlobSnapshot?> readSnapshot({
    required String userId,
    required String recordId,
  }) async {
    final snapshots = await readSnapshots(userId: userId);
    return snapshots[recordId];
  }

  Future<List<PushQueueItem>> readPushQueue({required String userId}) async {
    final raw = await _storage.read(_pushQueueKey(userId: userId));
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final payload = jsonDecode(raw) as List<dynamic>;
    return payload
        .cast<Map<String, dynamic>>()
        .map(PushQueueItem.fromJson)
        .toList(growable: true);
  }

  Future<void> savePushQueue({
    required String userId,
    required List<PushQueueItem> items,
  }) async {
    final encoded = items.map((item) => item.toJson()).toList(growable: false);
    await _storage.save(_pushQueueKey(userId: userId), jsonEncode(encoded));
  }

  Future<void> enqueuePushMutation({
    required String userId,
    required PushQueueItem item,
  }) async {
    final queue = await readPushQueue(userId: userId);
    queue.removeWhere(
      (existing) =>
          existing.localRecordId == item.localRecordId &&
          existing.status != PushQueueStatus.inFlight,
    );
    queue.add(item);
    await savePushQueue(userId: userId, items: queue);
  }

  bool _shouldApply({
    required RemoteVaultBlobSnapshot? existing,
    required RemoteVaultBlobChange incoming,
  }) {
    if (existing == null) {
      return true;
    }

    if (incoming.version > existing.version) {
      return true;
    }

    if (incoming.version < existing.version) {
      return false;
    }

    return incoming.updatedAt.isAfter(existing.updatedAt);
  }

  String _cursorKey({required String userId, required String deviceId}) {
    return '$_cursorPrefix:$userId:$deviceId';
  }

  String _lastPullKey({required String userId, required String deviceId}) {
    return '$_lastPullPrefix:$userId:$deviceId';
  }

  String _blobKey({required String userId}) {
    return '$_blobPrefix:$userId';
  }

  String _pushQueueKey({required String userId}) {
    return '$_pushQueuePrefix:$userId';
  }
}

enum PushQueueStatus { pending, inFlight, retry, failed }

enum PushQueueOperationKind { upsert, delete }

class PushQueueItem {
  const PushQueueItem({
    required this.opId,
    required this.localRecordId,
    required this.remoteRecordId,
    required this.kind,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.expectedVersion,
    this.ciphertext,
    this.nonce,
    this.aad,
    this.keyVersion,
    this.idempotencyKey,
    this.attemptCount = 0,
    this.retryCount = 0,
    this.nextAttemptAt,
    this.lastResultCode,
    this.lastMessage,
  });

  final String opId;
  final String localRecordId;
  final String remoteRecordId;
  final PushQueueOperationKind kind;
  final PushQueueStatus status;
  final int? expectedVersion;
  final String? ciphertext;
  final String? nonce;
  final String? aad;
  final int? keyVersion;
  final String? idempotencyKey;
  final int attemptCount;
  final int retryCount;
  final DateTime? nextAttemptAt;
  final String? lastResultCode;
  final String? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  PushQueueItem copyWith({
    PushQueueStatus? status,
    int? expectedVersion,
    String? idempotencyKey,
    int? attemptCount,
    int? retryCount,
    DateTime? nextAttemptAt,
    String? lastResultCode,
    String? lastMessage,
    DateTime? updatedAt,
  }) {
    return PushQueueItem(
      opId: opId,
      localRecordId: localRecordId,
      remoteRecordId: remoteRecordId,
      kind: kind,
      status: status ?? this.status,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      ciphertext: ciphertext,
      nonce: nonce,
      aad: aad,
      keyVersion: keyVersion,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      attemptCount: attemptCount ?? this.attemptCount,
      retryCount: retryCount ?? this.retryCount,
      nextAttemptAt: nextAttemptAt,
      lastResultCode: lastResultCode ?? this.lastResultCode,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PushQueueItem.fromMutation({
    required String opId,
    required String remoteRecordId,
    required LocalVaultMutation mutation,
  }) {
    return PushQueueItem(
      opId: opId,
      localRecordId: mutation.localRecordId,
      remoteRecordId: remoteRecordId,
      kind: mutation.kind == LocalVaultMutationKind.upsert
          ? PushQueueOperationKind.upsert
          : PushQueueOperationKind.delete,
      status: PushQueueStatus.pending,
      ciphertext: mutation.ciphertext,
      nonce: mutation.nonce,
      aad: mutation.aad,
      keyVersion: mutation.keyVersion,
      createdAt: mutation.occurredAt,
      updatedAt: mutation.occurredAt,
    );
  }

  factory PushQueueItem.fromJson(Map<String, dynamic> json) {
    return PushQueueItem(
      opId: json['opId'] as String,
      localRecordId: json['localRecordId'] as String,
      remoteRecordId: json['remoteRecordId'] as String,
      kind: _kindFromString(json['kind'] as String),
      status: _statusFromString(json['status'] as String),
      expectedVersion: json['expectedVersion'] as int?,
      ciphertext: json['ciphertext'] as String?,
      nonce: json['nonce'] as String?,
      aad: json['aad'] as String?,
      keyVersion: json['keyVersion'] as int?,
      idempotencyKey: json['idempotencyKey'] as String?,
      attemptCount: json['attemptCount'] as int? ?? 0,
      retryCount: json['retryCount'] as int? ?? 0,
      nextAttemptAt: json['nextAttemptAt'] == null
          ? null
          : DateTime.parse(json['nextAttemptAt'] as String).toUtc(),
      lastResultCode: json['lastResultCode'] as String?,
      lastMessage: json['lastMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'opId': opId,
      'localRecordId': localRecordId,
      'remoteRecordId': remoteRecordId,
      'kind': kind.name,
      'status': status.name,
      'expectedVersion': expectedVersion,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'aad': aad,
      'keyVersion': keyVersion,
      'idempotencyKey': idempotencyKey,
      'attemptCount': attemptCount,
      'retryCount': retryCount,
      'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
      'lastResultCode': lastResultCode,
      'lastMessage': lastMessage,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  static PushQueueOperationKind _kindFromString(String raw) {
    return switch (raw) {
      'upsert' => PushQueueOperationKind.upsert,
      'delete' => PushQueueOperationKind.delete,
      _ => PushQueueOperationKind.upsert,
    };
  }

  static PushQueueStatus _statusFromString(String raw) {
    return switch (raw) {
      'pending' => PushQueueStatus.pending,
      'inFlight' => PushQueueStatus.inFlight,
      'retry' => PushQueueStatus.retry,
      'failed' => PushQueueStatus.failed,
      _ => PushQueueStatus.pending,
    };
  }
}
