import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import 'package:gestor_contrasenas/core/security/biometric_auth_service.dart';
import 'package:gestor_contrasenas/core/security/master_password_service.dart';
import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/security/vault_security_controller.dart';

void main() {
  group('VaultSecurityController', () {
    test('creates and verifies master password flow', () async {
      final storage = _InMemorySecureStorageService();
      final controller = VaultSecurityController(
        storage: storage,
        masterPasswordService: MasterPasswordService(),
        biometricAuthService: const _FakeBiometricAuthService(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      final created = await controller.createMasterPassword(
        password: 'StrongPass!2026',
        confirmation: 'StrongPass!2026',
        enableBiometrics: true,
      );

      expect(created, isTrue);
      expect(controller.isUnlocked, isTrue);
      expect(
        await storage.read(VaultSecurityController.masterPasswordRecordKey),
        isNotNull,
      );
      expect(
        await storage.read(VaultSecurityController.biometricSeedKey),
        isNotNull,
      );

      await controller.lock();

      final unlocked = await controller.unlockWithPassword('StrongPass!2026');

      expect(unlocked, isTrue);
      expect(controller.isUnlocked, isTrue);
    });

    test('rejects weak master passwords', () async {
      final controller = VaultSecurityController(
        storage: _InMemorySecureStorageService(),
        masterPasswordService: MasterPasswordService(),
        biometricAuthService: const _FakeBiometricAuthService(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      final created = await controller.createMasterPassword(
        password: 'weak',
        confirmation: 'weak',
        enableBiometrics: false,
      );

      expect(created, isFalse);
      expect(controller.stage, VaultSecurityStage.onboarding);
      expect(controller.message, contains('12'));
    });

    test('locks on lifecycle background states when enabled', () async {
      final controller = VaultSecurityController(
        storage: _InMemorySecureStorageService(),
        masterPasswordService: MasterPasswordService(),
        biometricAuthService: const _FakeBiometricAuthService(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.createMasterPassword(
        password: 'StrongPass!2026',
        confirmation: 'StrongPass!2026',
        enableBiometrics: false,
      );

      expect(controller.isUnlocked, isTrue);

      await controller.handleAppLifecycleState(AppLifecycleState.paused);

      expect(controller.stage, VaultSecurityStage.locked);
      expect(
        controller.message,
        contains('bloqueada automaticamente al salir de primer plano'),
      );
    });

    test(
      'does not lock on lifecycle when background auto-lock disabled',
      () async {
        final controller = VaultSecurityController(
          storage: _InMemorySecureStorageService(),
          masterPasswordService: MasterPasswordService(),
          biometricAuthService: const _FakeBiometricAuthService(),
        );
        addTearDown(controller.dispose);

        await controller.initialize();
        await controller.createMasterPassword(
          password: 'StrongPass!2026',
          confirmation: 'StrongPass!2026',
          enableBiometrics: false,
        );
        await controller.setAutoLockOnBackgroundEnabled(false);

        await controller.handleAppLifecycleState(AppLifecycleState.paused);

        expect(controller.stage, VaultSecurityStage.unlocked);
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
  Future<bool> authenticateForUnlock() async => true;

  @override
  Future<BiometricAvailability> getAvailability() async {
    return const BiometricAvailability(
      deviceSupported: true,
      canCheckBiometrics: true,
      availableBiometrics: [BiometricType.strong],
    );
  }
}
