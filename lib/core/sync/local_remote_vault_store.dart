import 'dart:convert';

import '../security/secure_storage_service.dart';
import 'remote_vault_blob_change.dart';

class LocalRemoteVaultStore {
  LocalRemoteVaultStore({required SecureStorageService storage})
    : _storage = storage;

  static const _cursorPrefix = 'vault_sync_pull_cursor_v1';
  static const _lastPullPrefix = 'vault_sync_pull_last_at_v1';
  static const _blobPrefix = 'vault_sync_remote_blobs_v1';

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
}
