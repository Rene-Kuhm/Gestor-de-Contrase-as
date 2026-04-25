import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/sync/incremental_push_sync_service.dart';
import 'package:gestor_contrasenas/core/sync/local_remote_vault_store.dart';
import 'package:gestor_contrasenas/core/sync/local_vault_mutation.dart';
import 'package:gestor_contrasenas/core/sync/remote_vault_blob_change.dart';
import 'package:gestor_contrasenas/core/sync/remote_vault_sync_repository.dart';
import 'package:gestor_contrasenas/core/sync/sync_conflict.dart';

void main() {
  group('IncrementalPushSyncService', () {
    test('queues local upsert and clears queue when RPC applies', () async {
      final storage = _InMemorySecureStorageService();
      final localStore = LocalRemoteVaultStore(storage: storage);
      final repository = _FakeRemoteVaultSyncRepository(
        pushResponses: [
          const RemoteVaultPushResult(
            code: RemoteVaultPushResultCode.applied,
            applied: true,
            idempotentReplay: false,
            conflict: false,
            appliedVersion: 1,
          ),
        ],
      );

      final service = IncrementalPushSyncService(
        repository: repository,
        localStore: localStore,
        readDeviceId: () async => 'device-1',
        uuid: const Uuid(),
        now: () => DateTime.utc(2026, 3, 23, 14, 0),
      );

      await service.onLocalMutation(
        LocalVaultMutation.upsert(
          localRecordId: 'entry-1',
          ciphertext: 'cipher-a',
          nonce: 'nonce-a',
          aad: 'aad-a',
          keyVersion: 1,
          occurredAt: DateTime.utc(2026, 3, 23, 14, 0),
        ),
      );

      final queue = await localStore.readPushQueue(userId: 'user-1');
      final snapshots = await localStore.readSnapshots(userId: 'user-1');

      expect(queue, isEmpty);
      expect(repository.upsertCalls, hasLength(1));
      expect(snapshots, hasLength(1));
      expect(snapshots.values.first.version, 1);
    });

    test(
      'captures conflict details and marks queue item as conflict',
      () async {
        final storage = _InMemorySecureStorageService();
        final localStore = LocalRemoteVaultStore(storage: storage);
        final repository = _FakeRemoteVaultSyncRepository(
          pushResponses: [
            const RemoteVaultPushResult(
              code: RemoteVaultPushResultCode.casConflict,
              applied: false,
              idempotentReplay: false,
              conflict: true,
              currentVersion: 7,
              message: 'expected_version mismatch',
            ),
          ],
        );

        final service = IncrementalPushSyncService(
          repository: repository,
          localStore: localStore,
          readDeviceId: () async => 'device-1',
          now: () => DateTime.utc(2026, 3, 23, 14, 0),
        );

        await localStore.saveSnapshot(
          userId: 'user-1',
          snapshot: RemoteVaultBlobSnapshot(
            recordId: '5dc5d9a4-6f07-46d8-b897-e67f73dc5b9c',
            version: 3,
            keyVersion: 1,
            ciphertext: 'seed',
            nonce: 'seed',
            aad: 'seed',
            updatedAt: DateTime.utc(2026, 3, 23, 13, 0),
          ),
        );

        await service.onLocalMutation(
          LocalVaultMutation.delete(
            localRecordId: '5dc5d9a4-6f07-46d8-b897-e67f73dc5b9c',
            occurredAt: DateTime.utc(2026, 3, 23, 14, 0),
          ),
        );

        final queue = await localStore.readPushQueue(userId: 'user-1');
        final conflicts = await localStore.readPendingConflicts(
          userId: 'user-1',
        );
        expect(queue, hasLength(1));
        expect(queue.first.status, PushQueueStatus.conflict);
        expect(queue.first.lastResultCode, 'cas_conflict');
        expect(conflicts, hasLength(1));
        expect(conflicts.first.currentVersion, 7);
        expect(conflicts.first.kind, SyncConflictOperationKind.delete);
      },
    );

    test('keeps retry state and idempotency key on transient error', () async {
      final storage = _InMemorySecureStorageService();
      final localStore = LocalRemoteVaultStore(storage: storage);
      final repository = _FakeRemoteVaultSyncRepository(
        pushResponses: [
          const RemoteVaultPushResult(
            code: RemoteVaultPushResultCode.unknown,
            applied: false,
            idempotentReplay: false,
            conflict: false,
            message: 'timeout',
          ),
        ],
      );

      final service = IncrementalPushSyncService(
        repository: repository,
        localStore: localStore,
        readDeviceId: () async => 'device-1',
        baseBackoff: const Duration(seconds: 2),
        now: () => DateTime.utc(2026, 3, 23, 14, 0),
      );

      await service.onLocalMutation(
        LocalVaultMutation.upsert(
          localRecordId: 'entry-retry',
          ciphertext: 'cipher-r',
          nonce: 'nonce-r',
          aad: 'aad-r',
          keyVersion: 1,
          occurredAt: DateTime.utc(2026, 3, 23, 14, 0),
        ),
      );

      final queue = await localStore.readPushQueue(userId: 'user-1');
      expect(queue, hasLength(1));
      expect(queue.first.status, PushQueueStatus.retry);
      expect(queue.first.retryCount, 1);
      expect(queue.first.idempotencyKey, isNotNull);
      expect(queue.first.nextAttemptAt, DateTime.utc(2026, 3, 23, 14, 0, 2));
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
  _FakeRemoteVaultSyncRepository({
    required List<RemoteVaultPushResult> pushResponses,
  }) : _pushResponses = pushResponses;

  final List<RemoteVaultPushResult> _pushResponses;
  final List<Map<String, dynamic>> upsertCalls = [];
  final List<Map<String, dynamic>> deleteCalls = [];

  @override
  Future<List<RemoteVaultBlobChange>> fetchChangesSince({
    required int afterOpId,
    int limit = 200,
  }) async {
    return const [];
  }

  @override
  Future<RemoteVaultPushResult> pushDeleteBlob({
    required String deviceId,
    required String idempotencyKey,
    required String recordId,
    required int expectedVersion,
  }) async {
    deleteCalls.add({
      'deviceId': deviceId,
      'idempotencyKey': idempotencyKey,
      'recordId': recordId,
      'expectedVersion': expectedVersion,
    });
    return _nextResponse();
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
  }) async {
    upsertCalls.add({
      'deviceId': deviceId,
      'idempotencyKey': idempotencyKey,
      'recordId': recordId,
      'expectedVersion': expectedVersion,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'aad': aad,
      'keyVersion': keyVersion,
    });
    return _nextResponse();
  }

  @override
  Future<String?> readCurrentUserId() async => 'user-1';

  RemoteVaultPushResult _nextResponse() {
    if (_pushResponses.isEmpty) {
      return const RemoteVaultPushResult(
        code: RemoteVaultPushResultCode.applied,
        applied: true,
        idempotentReplay: false,
        conflict: false,
        appliedVersion: 1,
      );
    }

    return _pushResponses.removeAt(0);
  }
}
