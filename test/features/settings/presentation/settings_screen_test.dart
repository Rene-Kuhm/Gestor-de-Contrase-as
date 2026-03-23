import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:gestor_contrasenas/core/security/biometric_auth_service.dart';
import 'package:gestor_contrasenas/core/security/master_password_service.dart';
import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/security/vault_security_controller.dart';
import 'package:gestor_contrasenas/features/settings/presentation/settings_screen.dart';

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
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(securityController: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change master password'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'StrongPass!2026');
      await tester.enterText(find.byType(TextField).at(1), 'AnotherStrong!2027');
      await tester.enterText(find.byType(TextField).at(2), 'AnotherStrong!2027');

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
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(securityController: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change master password'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'WrongPass!2026');
      await tester.enterText(find.byType(TextField).at(1), 'AnotherStrong!2027');
      await tester.enterText(find.byType(TextField).at(2), 'AnotherStrong!2027');

      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Change master password'), findsOneWidget);
      expect(find.text('La master password actual no coincide.'), findsOneWidget);
    });
  });
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
