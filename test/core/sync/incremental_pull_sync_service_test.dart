import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:gestor_contrasenas/core/security/aes_gcm_vault_crypto_service.dart';
import 'package:gestor_contrasenas/core/security/biometric_auth_service.dart';
import 'package:gestor_contrasenas/core/security/local_encrypted_vault_repository.dart';
import 'package:gestor_contrasenas/core/security/master_password_service.dart';
import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/security/vault_security_controller.dart';
import 'package:gestor_contrasenas/core/sync/incremental_pull_sync_service.dart';
import 'package:gestor_contrasenas/core/sync/local_remote_vault_store.dart';
import 'package:gestor_contrasenas/core/sync/remote_vault_blob_change.dart';
import 'package:gestor_contrasenas/core/sync/remote_vault_sync_repository.dart';
import 'package:gestor_contrasenas/features/vault/domain/vault_item.dart';

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
          'gcm_tag': 'gcmTag',
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
      expect(change.gcmTag, isNull);
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
              gcmTag: 'aa1',
              updatedAt: DateTime.utc(2026, 3, 23, 12, 0),
            ),
            RemoteVaultBlobChange(
              opCursor: 7,
              recordId: 'record-b',
              version: 2,
              keyVersion: 1,
              ciphertext: 'b2',
              nonce: 'nb2',
              gcmTag: 'ab2',
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

      expect(repository.afterOpIds, [5]);
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
            gcmTag: 'gcmTag-v3',
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
            gcmTag: 'stale',
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

    test('retries transient fetch error and completes pull', () async {
      final storage = _InMemorySecureStorageService();
      final localStore = LocalRemoteVaultStore(storage: storage);
      final repository = _FakeRemoteVaultSyncRepository(
        batches: {
          0: [
            RemoteVaultBlobChange(
              opCursor: 1,
              recordId: 'record-retry',
              version: 1,
              keyVersion: 1,
              ciphertext: 'cipher',
              nonce: 'nonce',
              gcmTag: 'gcmTag',
              updatedAt: DateTime.utc(2026, 3, 23, 12, 0),
            ),
          ],
          1: const [],
        },
        failAfterOpIdCount: {0: 1},
      );

      final service = IncrementalPullSyncService(
        repository: repository,
        localStore: localStore,
        readDeviceId: () async => 'device-1',
        throttleInterval: const Duration(seconds: 1),
        delay: (_) async {},
        now: () => DateTime.utc(2026, 3, 23, 12, 30),
      );

      await service.onSessionStarted();

      final snapshots = await localStore.readSnapshots(userId: 'user-1');
      expect(snapshots['record-retry']?.version, 1);
      expect(repository.afterOpIds, [0, 0]);
    });

    test(
      'applies pulled encrypted blobs into local vault repository',
      () async {
        final storage = _InMemorySecureStorageService();
        final controller = VaultSecurityController(
          storage: storage,
          masterPasswordService: MasterPasswordService.test(),
          biometricAuthService: const _FakeBiometricAuthService(),
        );
        await controller.initialize();
        await controller.createMasterPassword(
          password: 'StrongPass!2026',
          confirmation: 'StrongPass!2026',
          enableBiometrics: false,
        );

        final localVault = LocalEncryptedVaultRepository(
          storage: storage,
          cryptoService: AesGcmVaultCryptoService(),
          readSession: () => controller.vaultSession,
        );
        final remoteItem = VaultItem(
          id: 'remote-mail',
          title: 'Remote Mail',
          username: 'remote@vaulta.app',
          secret: 'RemoteStrong!2026',
          category: VaultCategory.personal,
          strengthScore: 95,
          lastUpdatedLabel: 'now',
          updatedAt: DateTime.utc(2026, 3, 23, 12, 0),
        );
        final encrypted = await AesGcmVaultCryptoService().encrypt(
          plaintext: jsonEncode(remoteItem.toJson()),
          secretKey: controller.vaultSession!,
          keyId: controller.vaultSession!.keyId,
        );
        final payload = jsonDecode(encrypted) as Map<String, dynamic>;
        final encryptedPayload = payload['payload'] as Map<String, dynamic>;
        final remoteRepository = _FakeRemoteVaultSyncRepository(
          batches: {
            0: [
              RemoteVaultBlobChange(
                opCursor: 1,
                recordId: 'remote-mail',
                version: 1,
                keyVersion: 2,
                ciphertext: encryptedPayload['ciphertext_b64'] as String,
                nonce: encryptedPayload['nonce_b64'] as String,
                gcmTag: encryptedPayload['tag_b64'] as String,
                updatedAt: DateTime.utc(2026, 3, 23, 12, 0),
              ),
            ],
            1: const [],
          },
        );
        final service = IncrementalPullSyncService(
          repository: remoteRepository,
          localStore: LocalRemoteVaultStore(storage: storage),
          readDeviceId: () async => 'device-1',
          throttleInterval: const Duration(seconds: 1),
          applyLocalSnapshots: (snapshots) =>
              localVault.applyRemoteSnapshots(snapshots: snapshots),
          now: () => DateTime.utc(2026, 3, 23, 12, 30),
        );

        await service.onSessionStarted();

        final pulled = await localVault.fetchItemById('remote-mail');
        expect(pulled, isNotNull);
        expect(pulled!.secret, 'RemoteStrong!2026');
      },
    );
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

class _FakeBiometricAuthService implements BiometricAuthService {
  const _FakeBiometricAuthService();

  @override
  Future<bool> authenticateForUnlock() async => false;

  @override
  Future<BiometricAvailability> getAvailability() async {
    return const BiometricAvailability(
      deviceSupported: false,
      canCheckBiometrics: false,
      availableBiometrics: [],
    );
  }
}

class _FakeRemoteVaultSyncRepository implements RemoteVaultSyncRepository {
  _FakeRemoteVaultSyncRepository({
    required Map<int, List<RemoteVaultBlobChange>> batches,
    Map<int, int>? failAfterOpIdCount,
  }) : _batches = batches,
       _failAfterOpIdCount = failAfterOpIdCount ?? {};

  final Map<int, List<RemoteVaultBlobChange>> _batches;
  final Map<int, int> _failAfterOpIdCount;
  final List<int> afterOpIds = [];

  @override
  Future<List<RemoteVaultBlobChange>> fetchChangesSince({
    required int afterOpId,
    int limit = 200,
  }) async {
    afterOpIds.add(afterOpId);
    final failuresLeft = _failAfterOpIdCount[afterOpId] ?? 0;
    if (failuresLeft > 0) {
      _failAfterOpIdCount[afterOpId] = failuresLeft - 1;
      throw Exception('offline');
    }

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
    required String? gcmTag,
    required int keyVersion,
  }) {
    throw UnimplementedError();
  }
}
