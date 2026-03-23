import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:gestor_contrasenas/core/security/aes_gcm_vault_crypto_service.dart';
import 'package:gestor_contrasenas/core/security/biometric_auth_service.dart';
import 'package:gestor_contrasenas/core/security/local_encrypted_vault_repository.dart';
import 'package:gestor_contrasenas/core/security/master_password_service.dart';
import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/security/vault_security_controller.dart';
import 'package:gestor_contrasenas/features/vault/domain/vault_item.dart';

void main() {
  group('LocalEncryptedVaultRepository', () {
    test('stores encrypted items without plaintext leakage', () async {
      final storage = _InMemorySecureStorageService();
      final controller = VaultSecurityController(
        storage: storage,
        masterPasswordService: MasterPasswordService(),
        biometricAuthService: const _FakeBiometricAuthService(),
      );
      await controller.initialize();
      await controller.createMasterPassword(
        password: 'StrongPass!2026',
        confirmation: 'StrongPass!2026',
        enableBiometrics: false,
      );

      final repository = LocalEncryptedVaultRepository(
        storage: storage,
        cryptoService: AesGcmVaultCryptoService(),
        readSession: () => controller.vaultSession,
      );

      final saved = await repository.saveItem(
        const VaultItem(
          id: 'github',
          title: 'GitHub',
          username: 'leo@example.com',
          secret: 'VeryStrong!2026',
          category: VaultCategory.work,
          strengthScore: 0,
          lastUpdatedLabel: '',
        ),
      );
      final items = await repository.fetchItems();
      final stored = await storage.read(
        LocalEncryptedVaultRepository.encryptedVaultItemsKey,
      );

      expect(items, hasLength(1));
      expect(saved.strengthScore, greaterThan(80));
      expect(stored, isNotNull);
      expect(stored, isNot(contains('GitHub')));
      expect(stored, isNot(contains('VeryStrong!2026')));

      final encodedItems = (jsonDecode(stored!) as List<dynamic>)
          .cast<String>();
      final firstPayload =
          jsonDecode(encodedItems.first) as Map<String, dynamic>;
      expect(firstPayload['algorithm'], 'aes-256-gcm');
      expect(firstPayload['nonce'], isNotEmpty);
      expect(firstPayload['mac'], isNotEmpty);
    });

    test('fails when no vault session is available', () async {
      final repository = LocalEncryptedVaultRepository(
        storage: _InMemorySecureStorageService(),
        cryptoService: AesGcmVaultCryptoService(),
        readSession: () => null,
      );

      expect(repository.fetchItems(), throwsStateError);
    });

    test('creates updates and deletes encrypted entries', () async {
      final storage = _InMemorySecureStorageService();
      final controller = VaultSecurityController(
        storage: storage,
        masterPasswordService: MasterPasswordService(),
        biometricAuthService: const _FakeBiometricAuthService(),
      );
      await controller.initialize();
      await controller.createMasterPassword(
        password: 'StrongPass!2026',
        confirmation: 'StrongPass!2026',
        enableBiometrics: false,
      );

      final repository = LocalEncryptedVaultRepository(
        storage: storage,
        cryptoService: AesGcmVaultCryptoService(),
        readSession: () => controller.vaultSession,
      );

      await repository.saveItem(
        const VaultItem(
          id: 'bank',
          title: 'Bank',
          username: 'finance@vaulta.app',
          secret: 'BankPass!2026',
          category: VaultCategory.finance,
          strengthScore: 0,
          lastUpdatedLabel: '',
        ),
      );

      final created = await repository.fetchItemById('bank');
      expect(created, isNotNull);
      expect(created!.title, 'Bank');

      await repository.saveItem(
        created.copyWith(
          title: 'Primary Bank',
          secret: 'RotatedStrongPass#2026',
          notes: 'Updated after quarterly rotation.',
        ),
      );

      final updated = await repository.fetchItemById('bank');
      expect(updated, isNotNull);
      expect(updated!.title, 'Primary Bank');
      expect(updated.notes, 'Updated after quarterly rotation.');
      expect(updated.strengthScore, greaterThanOrEqualTo(created.strengthScore));

      await repository.deleteItem('bank');

      final items = await repository.fetchItems();
      expect(items, isEmpty);
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

class _FakeBiometricAuthService implements BiometricAuthService {
  const _FakeBiometricAuthService();

  @override
  Future<bool> authenticateForUnlock() async => true;

  @override
  Future<BiometricAvailability> getAvailability() async {
    return const BiometricAvailability(
      deviceSupported: true,
      canCheckBiometrics: true,
      availableBiometrics: [],
    );
  }
}
