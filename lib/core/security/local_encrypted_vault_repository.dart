import 'dart:convert';

import '../../features/vault/domain/vault_item.dart';
import '../../features/vault/domain/vault_summary.dart';
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
  }) : _storage = storage,
       _cryptoService = cryptoService,
       _readSession = readSession;

  static const encryptedVaultItemsKey = 'vault_encrypted_items_v1';

  static const securityPlan = PlatformSecurityPlan(
    secureStorage: true,
    biometricUnlock: true,
    hardwareBackedKeys: true,
    vaultEncryptionReady: true,
    notes:
        'Los items del vault se guardan cifrados con AES-256-GCM usando una clave derivada por PBKDF2-HMAC-SHA256 desde la master password. La clave vive solo en memoria de la sesion actual; rekeying, sync confiable y recovery siguen pendientes.',
  );

  final SecureStorageService _storage;
  final VaultCryptoService _cryptoService;
  final VaultSessionReader _readSession;

  @override
  Future<List<VaultItem>> fetchItems() async {
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
        secretKey: session.secretKey,
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

    await _saveEncryptedItems(items);
    return persisted;
  }

  @override
  Future<void> deleteItem(String id) async {
    final items = List<VaultItem>.of(await fetchItems());
    items.removeWhere((item) => item.id == id);
    await _saveEncryptedItems(items);
  }

  Future<void> _saveEncryptedItems(List<VaultItem> items) async {
    final session = _requireSession();
    final encryptedItems = <String>[];
    for (final item in items) {
      final encrypted = await _cryptoService.encrypt(
        plaintext: jsonEncode(item.toJson()),
        secretKey: session.secretKey,
        keyId: session.keyId,
      );
      encryptedItems.add(encrypted);
    }

    await _storage.save(encryptedVaultItemsKey, jsonEncode(encryptedItems));
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
