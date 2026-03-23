import 'package:flutter_test/flutter_test.dart';

import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/sync/incremental_pull_sync_service.dart';
import 'package:gestor_contrasenas/core/sync/local_remote_vault_store.dart';
import 'package:gestor_contrasenas/core/sync/remote_vault_blob_change.dart';
import 'package:gestor_contrasenas/core/sync/remote_vault_sync_repository.dart';

void main() {
  group('RemoteVaultBlobChange', () {
    test('parses supabase rows and preserves tombstone metadata', () {
      final change = RemoteVaultBlobChange.fromSupabaseRows(
        opRow: {'id': 42, 'record_id': 'record-01'},
        blobRow: {
          'record_id': 'record-01',
          'version': 7,
          'ciphertext': 'cipher-blob',
          'nonce': 'nonce',
          'aad': 'aad',
          'key_version': 3,
          'deleted_at': '2026-03-23T12:15:00Z',
          'updated_at': '2026-03-23T12:15:00Z',
        },
      );

      expect(change.opCursor, 42);
      expect(change.recordId, 'record-01');
      expect(change.version, 7);
      expect(change.keyVersion, 3);
      expect(change.isTombstone, isTrue);
      expect(change.ciphertext, isNull);
      expect(change.nonce, isNull);
      expect(change.aad, isNull);
    });
  });

  group('IncrementalPullSyncService', () {
    test('resumes from saved cursor and persists latest cursor', () async {
      final storage = _InMemorySecureStorageService();
      final localStore = LocalRemoteVaultStore(storage: storage);
      await localStore.saveCursor(
        userId: 'user-1',
        deviceId: 'device-1',
        cursor: 5,
      );
      await localStore.saveLastPullAt(
        userId: 'user-1',
        deviceId: 'device-1',
        lastPullAt: DateTime.utc(2026, 3, 23, 11, 0),
      );

      final repository = _FakeRemoteVaultSyncRepository(
        batches: {
          5: [
            RemoteVaultBlobChange(
              opCursor: 6,
              recordId: 'record-a',
              version: 1,
              keyVersion: 1,
              ciphertext: 'a1',
              nonce: 'na1',
              aad: 'aa1',
              updatedAt: DateTime.utc(2026, 3, 23, 12, 0),
            ),
            RemoteVaultBlobChange(
              opCursor: 7,
              recordId: 'record-b',
              version: 2,
              keyVersion: 1,
              ciphertext: 'b2',
              nonce: 'nb2',
              aad: 'ab2',
              updatedAt: DateTime.utc(2026, 3, 23, 12, 1),
            ),
          ],
          7: const [],
        },
      );

      final service = IncrementalPullSyncService(
        repository: repository,
        localStore: localStore,
        readDeviceId: () async => 'device-1',
        throttleInterval: const Duration(seconds: 1),
        now: () => DateTime.utc(2026, 3, 23, 12, 30),
      );

      await service.onSessionStarted();

      expect(repository.afterOpIds, [5, 7]);
      expect(
        await localStore.readCursor(userId: 'user-1', deviceId: 'device-1'),
        7,
      );
    });

    test('applies versioned updates and keeps latest tombstone', () async {
      final storage = _InMemorySecureStorageService();
      final localStore = LocalRemoteVaultStore(storage: storage);

      await localStore.applyChanges(
        userId: 'user-1',
        deviceId: 'device-1',
        newCursor: 10,
        changes: [
          RemoteVaultBlobChange(
            opCursor: 10,
            recordId: 'record-x',
            version: 3,
            keyVersion: 1,
            ciphertext: 'cipher-v3',
            nonce: 'nonce-v3',
            aad: 'aad-v3',
            updatedAt: DateTime.utc(2026, 3, 23, 12, 0),
          ),
        ],
      );

      await localStore.applyChanges(
        userId: 'user-1',
        deviceId: 'device-1',
        newCursor: 11,
        changes: [
          RemoteVaultBlobChange(
            opCursor: 11,
            recordId: 'record-x',
            version: 2,
            keyVersion: 1,
            ciphertext: 'stale',
            nonce: 'stale',
            aad: 'stale',
            updatedAt: DateTime.utc(2026, 3, 23, 11, 59),
          ),
        ],
      );

      await localStore.applyChanges(
        userId: 'user-1',
        deviceId: 'device-1',
        newCursor: 12,
        changes: [
          RemoteVaultBlobChange(
            opCursor: 12,
            recordId: 'record-x',
            version: 4,
            keyVersion: 1,
            deletedAt: DateTime.utc(2026, 3, 23, 12, 5),
            updatedAt: DateTime.utc(2026, 3, 23, 12, 5),
          ),
        ],
      );

      final snapshots = await localStore.readSnapshots(userId: 'user-1');
      final snapshot = snapshots['record-x'];

      expect(snapshot, isNotNull);
      expect(snapshot!.version, 4);
      expect(snapshot.isTombstone, isTrue);
      expect(snapshot.ciphertext, isNull);
      expect(
        await localStore.readCursor(userId: 'user-1', deviceId: 'device-1'),
        12,
      );
    });
  });
}

class _InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> save(String key, String value) async {
    _values[key] = value;
  }
}

class _FakeRemoteVaultSyncRepository implements RemoteVaultSyncRepository {
  _FakeRemoteVaultSyncRepository({required Map<int, List<RemoteVaultBlobChange>> batches})
    : _batches = batches;

  final Map<int, List<RemoteVaultBlobChange>> _batches;
  final List<int> afterOpIds = [];

  @override
  Future<List<RemoteVaultBlobChange>> fetchChangesSince({
    required int afterOpId,
    int limit = 200,
  }) async {
    afterOpIds.add(afterOpId);
    return _batches[afterOpId] ?? const [];
  }

  @override
  Future<String?> readCurrentUserId() async => 'user-1';

  @override
  Future<RemoteVaultPushResult> pushDeleteBlob({
    required String deviceId,
    required String idempotencyKey,
    required String recordId,
    required int expectedVersion,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RemoteVaultPushResult> pushUpsertBlob({
    required String deviceId,
    required String idempotencyKey,
    required String recordId,
    required int? expectedVersion,
    required String ciphertext,
    required String nonce,
    required String? aad,
    required int keyVersion,
  }) {
    throw UnimplementedError();
  }
}
