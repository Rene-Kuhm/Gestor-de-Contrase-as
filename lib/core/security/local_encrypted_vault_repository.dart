import 'dart:convert';
import 'dart:async';

import '../../features/vault/domain/vault_item.dart';
import '../../features/vault/domain/vault_summary.dart';
import '../sync/local_vault_mutation.dart';
import '../sync/remote_vault_blob_change.dart';
import 'platform_security_plan.dart';
import 'secure_storage_service.dart';
import 'vault_crypto_service.dart';
import 'vault_repository.dart';
import 'vault_session.dart';

typedef VaultSessionReader = VaultSession? Function();

class LocalEncryptedVaultRepository implements VaultRepository {
  LocalEncryptedVaultRepository({
    required SecureStorageService storage,
    required VaultCryptoService cryptoService,
    required VaultSessionReader readSession,
    LocalVaultMutationSink? mutationSink,
  }) : _storage = storage,
       _cryptoService = cryptoService,
       _readSession = readSession,
       _mutationSink = mutationSink;

  static const encryptedVaultItemsKey = 'vault_encrypted_items_v1';
  static const encryptedVaultItemsStagingKey =
      'vault_encrypted_items_v1_staging';
  static const rekeyInProgressKey = 'vault_rekey_in_progress_v1';

  static const securityPlan = PlatformSecurityPlan(
    secureStorage: true,
    biometricUnlock: false,
    hardwareBackedKeys: false,
    vaultEncryptionReady: true,
    notes:
        'Los items del vault se guardan con formato v2: KEK Argon2id desde master password, DEK aleatoria por vault, DEK envuelta con AES-256-GCM y payloads AES-256-GCM. La DEK vive solo en memoria de sesion. Biometria queda como verificacion de UX y no desbloqueo criptografico porque local_auth no ata claves a hardware por si solo.',
  );

  final SecureStorageService _storage;
  final VaultCryptoService _cryptoService;
  final VaultSessionReader _readSession;
  final LocalVaultMutationSink? _mutationSink;

  @override
  Future<List<VaultItem>> fetchItems() async {
    await _recoverFromInterruptedRekey();
    final session = _requireSession();
    final raw = await _storage.read(encryptedVaultItemsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final encryptedItems = (jsonDecode(raw) as List<dynamic>).cast<String>();
    final items = <VaultItem>[];

    for (final encrypted in encryptedItems) {
      final plaintext = await _cryptoService.decrypt(
        ciphertext: encrypted,
        secretKey: session,
        expectedKeyId: session.keyId,
      );
      items.add(
        VaultItem.fromJson(jsonDecode(plaintext) as Map<String, dynamic>),
      );
    }

    items.sort((left, right) {
      final leftUpdated = left.updatedAt;
      final rightUpdated = right.updatedAt;
      if (leftUpdated == null && rightUpdated == null) {
        return right.lastUpdatedLabel.compareTo(left.lastUpdatedLabel);
      }
      if (leftUpdated == null) {
        return 1;
      }
      if (rightUpdated == null) {
        return -1;
      }
      return rightUpdated.compareTo(leftUpdated);
    });

    return items;
  }

  @override
  Future<VaultSummary> fetchSummary() async {
    final items = await fetchItems();
    final weakItems = items.where((item) => item.strengthScore < 80).length;
    final reusedItems = _countReusedSecrets(items);
    final averageScore = items.isEmpty
        ? 0
        : items.fold<int>(0, (sum, item) => sum + item.strengthScore) ~/
              items.length;

    return VaultSummary(
      totalItems: items.length,
      weakItems: weakItems,
      reusedItems: reusedItems,
      securityScore: averageScore,
      connectedDevices: 1,
      syncEnabled: false,
    );
  }

  @override
  Future<VaultItem?> fetchItemById(String id) async {
    final items = await fetchItems();
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<VaultItem> saveItem(VaultItem item) async {
    final items = List<VaultItem>.of(await fetchItems());
    final now = DateTime.now();
    final persisted = item.copyWith(
      strengthScore: estimatePasswordStrength(item.secret),
      updatedAt: now,
      lastUpdatedLabel: formatVaultUpdatedLabel(now, now: now),
    );
    final index = items.indexWhere((candidate) => candidate.id == persisted.id);

    if (index == -1) {
      items.add(persisted);
    } else {
      items[index] = persisted;
    }

    final encryptedById = await _saveEncryptedItems(items);
    final syncPayload = _extractSyncPayload(encryptedById[persisted.id]);
    if (syncPayload != null) {
      unawaited(
        _mutationSink
            ?.onLocalMutation(
              LocalVaultMutation.upsert(
                localRecordId: persisted.id,
                ciphertext: syncPayload.ciphertext,
                nonce: syncPayload.nonce,
                aad: syncPayload.aad,
                keyVersion: syncPayload.keyVersion,
                occurredAt: now.toUtc(),
              ),
            )
            .catchError((_) {}),
      );
    }
    return persisted;
  }

  @override
  Future<void> deleteItem(String id) async {
    final items = List<VaultItem>.of(await fetchItems());
    items.removeWhere((item) => item.id == id);
    await _saveEncryptedItems(items);
    unawaited(
      _mutationSink
          ?.onLocalMutation(
            LocalVaultMutation.delete(
              localRecordId: id,
              occurredAt: DateTime.now().toUtc(),
            ),
          )
          .catchError((_) {}),
    );
  }

  Future<void> rekeyEntries({
    required VaultSession sourceSession,
    required VaultSession targetSession,
  }) async {
    await _recoverFromInterruptedRekey();

    final raw = await _storage.read(encryptedVaultItemsKey);
    if (raw == null || raw.isEmpty) {
      await _clearRekeyArtifacts(swallowErrors: true);
      return;
    }

    final encryptedItems = (jsonDecode(raw) as List<dynamic>).cast<String>();
    final reencryptedItems = <String>[];

    for (final encrypted in encryptedItems) {
      final plaintext = await _cryptoService.decrypt(
        ciphertext: encrypted,
        secretKey: sourceSession,
        expectedKeyId: sourceSession.keyId,
      );
      final reencrypted = await _cryptoService.encrypt(
        plaintext: plaintext,
        secretKey: targetSession,
        keyId: targetSession.keyId,
      );
      reencryptedItems.add(reencrypted);
    }

    final stagedPayload = jsonEncode(reencryptedItems);

    await _storage.save(rekeyInProgressKey, 'true');
    await _storage.save(encryptedVaultItemsStagingKey, stagedPayload);

    try {
      await _storage.save(encryptedVaultItemsKey, stagedPayload);
    } catch (_) {
      final committed = await _didSwapCommit(stagedPayload);
      if (!committed) {
        await _clearRekeyArtifacts(swallowErrors: true);
        rethrow;
      }
    }

    await _clearRekeyArtifacts(swallowErrors: true);
  }

  Future<Map<String, String>> _saveEncryptedItems(List<VaultItem> items) async {
    await _recoverFromInterruptedRekey();
    final session = _requireSession();
    final encryptedItems = <String>[];
    final encryptedById = <String, String>{};
    for (final item in items) {
      final encrypted = await _cryptoService.encrypt(
        plaintext: jsonEncode(item.toJson()),
        secretKey: session,
        keyId: session.keyId,
      );
      encryptedItems.add(encrypted);
      encryptedById[item.id] = encrypted;
    }

    await _storage.save(encryptedVaultItemsKey, jsonEncode(encryptedItems));
    return encryptedById;
  }

  _SyncBlobPayload? _extractSyncPayload(String? encryptedItemPayload) {
    if (encryptedItemPayload == null || encryptedItemPayload.isEmpty) {
      return null;
    }

    final payload = jsonDecode(encryptedItemPayload);
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final nestedPayload = payload['payload'] is Map<String, dynamic>
        ? payload['payload'] as Map<String, dynamic>
        : payload;
    final ciphertext =
        (nestedPayload['ciphertext_b64'] ?? nestedPayload['ciphertext'])
            as String?;
    final nonce =
        (nestedPayload['nonce_b64'] ?? nestedPayload['nonce']) as String?;
    final aad = (nestedPayload['tag_b64'] ?? nestedPayload['mac']) as String?;

    if (ciphertext == null ||
        ciphertext.isEmpty ||
        nonce == null ||
        nonce.isEmpty) {
      return null;
    }

    return _SyncBlobPayload(
      ciphertext: ciphertext,
      nonce: nonce,
      aad: aad,
      keyVersion: (payload['v'] ?? payload['version'] ?? 1) as int,
    );
  }

  Future<void> applyRemoteSnapshots({
    required Iterable<RemoteVaultBlobSnapshot> snapshots,
  }) async {
    await _recoverFromInterruptedRekey();
    final session = _requireSession();
    final currentItems = <String, VaultItem>{
      for (final item in await fetchItems()) item.id: item,
    };

    for (final snapshot in snapshots) {
      final localId = snapshot.recordId;
      if (snapshot.isTombstone) {
        currentItems.remove(localId);
        continue;
      }
      final encrypted = _encryptedPayloadFromSnapshot(snapshot);
      if (encrypted == null) {
        continue;
      }
      final plaintext = await _cryptoService.decrypt(
        ciphertext: encrypted,
        secretKey: session,
        expectedKeyId: session.keyId,
      );
      final item = VaultItem.fromJson(
        jsonDecode(plaintext) as Map<String, dynamic>,
      );
      currentItems[item.id] = item;
    }

    await _saveEncryptedItems(currentItems.values.toList(growable: false));
  }

  String? _encryptedPayloadFromSnapshot(RemoteVaultBlobSnapshot snapshot) {
    final ciphertext = snapshot.ciphertext;
    final nonce = snapshot.nonce;
    if (ciphertext == null ||
        ciphertext.isEmpty ||
        nonce == null ||
        nonce.isEmpty) {
      return null;
    }
    final session = _requireSession();
    if (snapshot.keyVersion == 2 && session.isV2) {
      return jsonEncode({
        'v': 2,
        'keyId': session.keyId,
        'kdf': session.kdf,
        'dek_wrap': session.dekWrap,
        'payload': {
          'alg': 'AES-256-GCM',
          'nonce_b64': nonce,
          'ciphertext_b64': ciphertext,
          'tag_b64': snapshot.aad ?? '',
        },
      });
    }
    return jsonEncode({
      'version': 1,
      'algorithm': 'aes-256-gcm',
      'keyId': session.keyId,
      'nonce': nonce,
      'ciphertext': ciphertext,
      'mac': snapshot.aad ?? '',
    });
  }

  Future<void> _recoverFromInterruptedRekey() async {
    final marker = await _storage.read(rekeyInProgressKey);
    if (marker != 'true') {
      final staleStaging = await _storage.read(encryptedVaultItemsStagingKey);
      if (staleStaging != null) {
        await _storage.delete(encryptedVaultItemsStagingKey);
      }
      return;
    }

    await _clearRekeyArtifacts(swallowErrors: true);
  }

  Future<bool> _didSwapCommit(String expectedPayload) async {
    final committedPayload = await _storage.read(encryptedVaultItemsKey);
    return committedPayload == expectedPayload;
  }

  Future<void> _clearRekeyArtifacts({required bool swallowErrors}) async {
    Future<void> runDelete(String key) async {
      try {
        await _storage.delete(key);
      } catch (_) {
        if (!swallowErrors) {
          rethrow;
        }
      }
    }

    await runDelete(encryptedVaultItemsStagingKey);
    await runDelete(rekeyInProgressKey);
  }

  VaultSession _requireSession() {
    final session = _readSession();
    if (session == null) {
      throw StateError(
        'Vault encryption key unavailable. Unlock with the master password first.',
      );
    }
    return session;
  }

  int _countReusedSecrets(List<VaultItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      counts.update(item.secret, (current) => current + 1, ifAbsent: () => 1);
    }

    return counts.values
        .where((count) => count > 1)
        .fold<int>(0, (sum, count) => sum + count);
  }
}

class _SyncBlobPayload {
  const _SyncBlobPayload({
    required this.ciphertext,
    required this.nonce,
    required this.aad,
    required this.keyVersion,
  });

  final String ciphertext;
  final String nonce;
  final String? aad;
  final int keyVersion;
}
