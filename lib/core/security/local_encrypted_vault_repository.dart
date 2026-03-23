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
  Future<List<VaultItem>> fetchRecentItems() async {
    await _ensureSeedData();
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

    return items;
  }

  @override
  Future<VaultSummary> fetchSummary() async {
    final items = await fetchRecentItems();
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

  Future<void> _ensureSeedData() async {
    final existing = await _storage.read(encryptedVaultItemsKey);
    if (existing != null && existing.isNotEmpty) {
      return;
    }

    final session = _requireSession();
    final encryptedItems = <String>[];
    for (final item in _seedItems) {
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

  List<VaultItem> get _seedItems => const [
    VaultItem(
      id: 'figma-workspace',
      title: 'Figma Workspace',
      username: 'product@vaulta.app',
      secret: 'StudioPrototype!2026',
      category: VaultCategory.work,
      strengthScore: 96,
      lastUpdatedLabel: 'Updated 2d ago',
    ),
    VaultItem(
      id: 'mercado-pago',
      title: 'Mercado Pago',
      username: 'finanzas@vaulta.app',
      secret: 'LedgerShield#8841',
      category: VaultCategory.finance,
      strengthScore: 88,
      lastUpdatedLabel: 'Updated today',
    ),
    VaultItem(
      id: 'notion-personal',
      title: 'Notion Personal',
      username: 'leo@vaulta.app',
      secret: 'StudioPrototype!2026',
      category: VaultCategory.personal,
      strengthScore: 72,
      lastUpdatedLabel: 'Review now',
    ),
  ];
}
