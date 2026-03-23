import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:gestor_contrasenas/app/localization/app_locale_controller.dart';
import 'package:gestor_contrasenas/core/security/biometric_auth_service.dart';
import 'package:gestor_contrasenas/core/security/master_password_service.dart';
import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/security/vault_security_controller.dart';
import 'package:gestor_contrasenas/core/sync/device_registration_repository.dart';
import 'package:gestor_contrasenas/core/sync/device_registration_service.dart';
import 'package:gestor_contrasenas/core/sync/device_session_revocation_service.dart';
import 'package:gestor_contrasenas/features/settings/presentation/settings_screen.dart';
import 'package:gestor_contrasenas/l10n/app_localizations.dart';

void main() {
  group('SettingsScreen change master password', () {
    testWidgets('updates master password and closes dialog on success', (
      tester,
    ) async {
      var rekeyCalls = 0;
      final controller = await _buildUnlockedController(
        rekeyEntries: ({required sourceSession, required targetSession}) async {
          rekeyCalls += 1;
        },
      );
      final localeController = AppLocaleController(
        storage: _InMemorySecureStorageService(),
      );
      await localeController.initialize();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _testApp(
          SettingsScreen(
            securityController: controller,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change master password'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'StrongPass!2026');
      await tester.enterText(
        find.byType(TextField).at(1),
        'AnotherStrong!2027',
      );
      await tester.enterText(
        find.byType(TextField).at(2),
        'AnotherStrong!2027',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Change master password'), findsNothing);
      expect(
        find.text('Master password actualizada correctamente.'),
        findsOneWidget,
      );
      expect(rekeyCalls, 1);

      await controller.lock();
      expect(await controller.unlockWithPassword('StrongPass!2026'), isFalse);
      expect(await controller.unlockWithPassword('AnotherStrong!2027'), isTrue);
    });

    testWidgets('shows error feedback when current password is invalid', (
      tester,
    ) async {
      final controller = await _buildUnlockedController();
      final localeController = AppLocaleController(
        storage: _InMemorySecureStorageService(),
      );
      await localeController.initialize();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _testApp(
          SettingsScreen(
            securityController: controller,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change master password'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'WrongPass!2026');
      await tester.enterText(
        find.byType(TextField).at(1),
        'AnotherStrong!2027',
      );
      await tester.enterText(
        find.byType(TextField).at(2),
        'AnotherStrong!2027',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Change master password'), findsOneWidget);
      expect(
        find.text('La master password actual no coincide.'),
        findsOneWidget,
      );
    });

    testWidgets('updates idle timeout preset from settings', (tester) async {
      final controller = await _buildUnlockedController();
      final localeController = AppLocaleController(
        storage: _InMemorySecureStorageService(),
      );
      await localeController.initialize();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _testApp(
          SettingsScreen(
            securityController: controller,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.idleTimeoutSeconds, 300);

      await tester.tap(find.byType(DropdownButtonFormField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Never - Disabled').last);
      await tester.pumpAndSettle();

      expect(controller.idleTimeoutSeconds, 0);
      expect(controller.message, contains('inactividad desactivado'));
    });

    testWidgets('renders device sessions and revokes selected device', (
      tester,
    ) async {
      final controller = await _buildUnlockedController();
      final localeController = AppLocaleController(
        storage: _InMemorySecureStorageService(),
      );
      await localeController.initialize();
      final repository = _FakeDeviceRegistrationRepository(
        devices: const [
          VaultDeviceSession(
            deviceId: 'test-device-id',
            deviceName: 'Pixel 8',
            platform: 'android',
            appVersion: '1.0.0+1',
            status: DeviceSessionStatus.active,
            accessAllowed: true,
          ),
          VaultDeviceSession(
            deviceId: 'old-laptop',
            deviceName: 'Old Laptop',
            platform: 'windows',
            appVersion: '1.0.0+1',
            status: DeviceSessionStatus.revokedAll,
            accessAllowed: false,
          ),
        ],
      );
      final revocationService = DeviceSessionRevocationService(
        repository: repository,
        identityService: const _FakeDeviceIdentityService('current-device'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _testApp(
          SettingsScreen(
            securityController: controller,
            localeController: localeController,
            revocationService: revocationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Devices and sessions'), findsOneWidget);
      expect(find.text('status: active'), findsOneWidget);
      expect(find.text('status: revoked_all'), findsOneWidget);

      await tester.tap(find.text('Revoke device'));
      await tester.pumpAndSettle();

      expect(repository.lastRevokedDeviceId, 'test-device-id');
    });

    testWidgets('locks current session when current device is revoked', (
      tester,
    ) async {
      final controller = await _buildUnlockedController();
      final localeController = AppLocaleController(
        storage: _InMemorySecureStorageService(),
      );
      await localeController.initialize();
      final repository = _FakeDeviceRegistrationRepository(
        devices: const [
          VaultDeviceSession(
            deviceId: 'current-device',
            deviceName: 'Pixel 8',
            platform: 'android',
            appVersion: '1.0.0+1',
            status: DeviceSessionStatus.active,
            accessAllowed: true,
          ),
        ],
      );
      final revocationService = DeviceSessionRevocationService(
        repository: repository,
        identityService: const _FakeDeviceIdentityService('current-device'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _testApp(
          SettingsScreen(
            securityController: controller,
            localeController: localeController,
            revocationService: revocationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Revoke device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke now'));
      await tester.pumpAndSettle();

      expect(controller.stage, VaultSecurityStage.locked);
      expect(controller.message, contains('se revoco en este dispositivo'));
    });

    testWidgets('revokes all other devices with current device id', (
      tester,
    ) async {
      final controller = await _buildUnlockedController();
      final localeController = AppLocaleController(
        storage: _InMemorySecureStorageService(),
      );
      await localeController.initialize();
      final repository = _FakeDeviceRegistrationRepository(
        devices: const [
          VaultDeviceSession(
            deviceId: 'current-device',
            deviceName: 'Pixel 8',
            platform: 'android',
            appVersion: '1.0.0+1',
            status: DeviceSessionStatus.active,
            accessAllowed: true,
          ),
        ],
      );
      final revocationService = DeviceSessionRevocationService(
        repository: repository,
        identityService: const _FakeDeviceIdentityService('current-device'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _testApp(
          SettingsScreen(
            securityController: controller,
            localeController: localeController,
            revocationService: revocationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Revoke all other sessions'));
      await tester.pumpAndSettle();

      expect(repository.lastRevokeAllCurrentDeviceId, 'current-device');
      expect(repository.revokeAllOtherCalls, 1);
    });
  });
}

Widget _testApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

Future<VaultSecurityController> _buildUnlockedController({
  VaultRekeyEntries? rekeyEntries,
}) async {
  final controller = VaultSecurityController(
    storage: _InMemorySecureStorageService(),
    masterPasswordService: MasterPasswordService(),
    biometricAuthService: const _FakeBiometricAuthService(),
    rekeyEntries: rekeyEntries,
  );

  await controller.initialize();
  await controller.createMasterPassword(
    password: 'StrongPass!2026',
    confirmation: 'StrongPass!2026',
    enableBiometrics: false,
  );
  await controller.setIdleTimeoutSeconds(0);

  return controller;
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

class _FakeDeviceIdentityService implements DeviceIdentityService {
  const _FakeDeviceIdentityService(this._deviceId);

  final String _deviceId;

  @override
  Future<String> getOrCreateDeviceId() async => _deviceId;

  @override
  String readPlatform() => 'android';

  @override
  Future<String> readDeviceName() async => 'Pixel 8';
}

class _FakeDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  _FakeDeviceRegistrationRepository({required this.devices});

  final List<VaultDeviceSession> devices;
  String? lastRevokedDeviceId;
  String? lastRevokeAllCurrentDeviceId;
  int revokeAllOtherCalls = 0;

  @override
  Future<List<VaultDeviceSession>> listDevices() async => devices;

  @override
  Future<DeviceAccessStatus> readDeviceAccessStatus({
    required String deviceId,
  }) async {
    return const DeviceAccessStatus(accessAllowed: true, reason: null);
  }

  @override
  Future<DeviceAccessStatus> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  }) async {
    return const DeviceAccessStatus(accessAllowed: true, reason: null);
  }

  @override
  Future<void> revokeAllOtherDevices({required String currentDeviceId}) async {
    revokeAllOtherCalls += 1;
    lastRevokeAllCurrentDeviceId = currentDeviceId;
  }

  @override
  Future<void> revokeDevice({required String deviceId}) async {
    lastRevokedDeviceId = deviceId;
  }

  @override
  Future<DeviceAccessStatus> sendHeartbeat({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  }) async {
    return const DeviceAccessStatus(accessAllowed: true, reason: null);
  }
}
