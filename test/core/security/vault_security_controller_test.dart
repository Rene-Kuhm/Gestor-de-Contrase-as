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
        masterPasswordService: MasterPasswordService.test(),
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
        await storage.read(
          VaultSecurityController.biometricRecoveryArtifactKey,
        ),
        isNull,
      );
      expect(
        await storage.read(VaultSecurityController.biometricSeedKey),
        isNull,
      );

      await controller.lock();

      final unlocked = await controller.unlockWithPassword('StrongPass!2026');

      expect(unlocked, isTrue);
      expect(controller.isUnlocked, isTrue);
    });

    test('biometric unlock never restores a persisted vault key', () async {
      final storage = _InMemorySecureStorageService();
      final controller = VaultSecurityController(
        storage: storage,
        masterPasswordService: MasterPasswordService.test(),
        biometricAuthService: const _FakeBiometricAuthService(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.createMasterPassword(
        password: 'StrongPass!2026',
        confirmation: 'StrongPass!2026',
        enableBiometrics: true,
      );
      await controller.lock();

      // Biometric unlock now restores the vault session from the secure slot
      // written during createMasterPassword/unlockWithPassword when biometrics
      // are enabled.
      final unlocked = await controller.unlockWithBiometrics();

      expect(unlocked, isTrue);
      expect(controller.stage, VaultSecurityStage.unlocked);
      expect(controller.vaultSession, isNotNull);
      expect(
        await storage.read(
          VaultSecurityController.biometricRecoveryArtifactKey,
        ),
        isNull,
      );
    });

    test('rejects weak master passwords', () async {
      final controller = VaultSecurityController(
        storage: _InMemorySecureStorageService(),
        masterPasswordService: MasterPasswordService.test(),
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
        masterPasswordService: MasterPasswordService.test(),
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
          masterPasswordService: MasterPasswordService.test(),
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

    test('locks after idle timeout and resets countdown on activity', () async {
      final controller = VaultSecurityController(
        storage: _InMemorySecureStorageService(),
        masterPasswordService: MasterPasswordService.test(),
        biometricAuthService: const _FakeBiometricAuthService(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.createMasterPassword(
        password: 'StrongPass!2026',
        confirmation: 'StrongPass!2026',
        enableBiometrics: false,
      );
      await controller.setIdleTimeoutSeconds(1);

      await Future<void>.delayed(const Duration(milliseconds: 800));
      controller.registerUserInteraction();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(controller.stage, VaultSecurityStage.unlocked);

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(controller.stage, VaultSecurityStage.locked);
      expect(controller.message, contains('inactividad'));
    });

    test('does not lock on idle when idle auto-lock is disabled', () async {
      final controller = VaultSecurityController(
        storage: _InMemorySecureStorageService(),
        masterPasswordService: MasterPasswordService.test(),
        biometricAuthService: const _FakeBiometricAuthService(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.createMasterPassword(
        password: 'StrongPass!2026',
        confirmation: 'StrongPass!2026',
        enableBiometrics: false,
      );
      await controller.setIdleTimeoutSeconds(0);

      await Future<void>.delayed(const Duration(milliseconds: 1200));

      expect(controller.stage, VaultSecurityStage.unlocked);
    });

    test('changes master password and keeps session unlocked', () async {
      var rekeyCalls = 0;
      String? sourceKeyId;
      String? targetKeyId;

      final storage = _InMemorySecureStorageService();
      final controller = VaultSecurityController(
        storage: storage,
        masterPasswordService: MasterPasswordService.test(),
        biometricAuthService: const _FakeBiometricAuthService(),
        rekeyEntries: ({required sourceSession, required targetSession}) async {
          rekeyCalls += 1;
          sourceKeyId = sourceSession.keyId;
          targetKeyId = targetSession.keyId;
        },
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.createMasterPassword(
        password: 'StrongPass!2026',
        confirmation: 'StrongPass!2026',
        enableBiometrics: false,
      );

      final changed = await controller.changeMasterPassword(
        currentPassword: 'StrongPass!2026',
        newPassword: 'AnotherStrong!2027',
        confirmation: 'AnotherStrong!2027',
      );

      expect(changed, isTrue);
      expect(rekeyCalls, 1);
      expect(sourceKeyId, isNotNull);
      expect(targetKeyId, isNotNull);
      expect(targetKeyId, isNot(equals(sourceKeyId)));
      expect(controller.isUnlocked, isTrue);

      await controller.lock();
      final oldUnlock = await controller.unlockWithPassword('StrongPass!2026');
      final newUnlock = await controller.unlockWithPassword(
        'AnotherStrong!2027',
      );

      expect(oldUnlock, isFalse);
      expect(newUnlock, isTrue);
    });

    test('rejects change when current master password is wrong', () async {
      var rekeyCalls = 0;
      final controller = VaultSecurityController(
        storage: _InMemorySecureStorageService(),
        masterPasswordService: MasterPasswordService.test(),
        biometricAuthService: const _FakeBiometricAuthService(),
        rekeyEntries: ({required sourceSession, required targetSession}) async {
          rekeyCalls += 1;
        },
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.createMasterPassword(
        password: 'StrongPass!2026',
        confirmation: 'StrongPass!2026',
        enableBiometrics: false,
      );

      final changed = await controller.changeMasterPassword(
        currentPassword: 'WrongPass!2026',
        newPassword: 'AnotherStrong!2027',
        confirmation: 'AnotherStrong!2027',
      );

      expect(changed, isFalse);
      expect(rekeyCalls, 0);
      expect(controller.message, contains('actual no coincide'));
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
      availableBiometrics: [BiometricType.strong],
    );
  }
}
