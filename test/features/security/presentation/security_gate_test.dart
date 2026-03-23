import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:gestor_contrasenas/core/security/biometric_auth_service.dart';
import 'package:gestor_contrasenas/core/security/master_password_service.dart';
import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/security/vault_security_controller.dart';
import 'package:gestor_contrasenas/features/security/presentation/security_gate.dart';

void main() {
  testWidgets('locks gate when app moves to background state', (tester) async {
    final controller = VaultSecurityController(
      storage: _InMemorySecureStorageService(),
      masterPasswordService: MasterPasswordService(),
      biometricAuthService: const _FakeBiometricAuthService(),
    );
    addTearDown(() async {
      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await controller.initialize();
    await controller.createMasterPassword(
      password: 'StrongPass!2026',
      confirmation: 'StrongPass!2026',
      enableBiometrics: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SecurityGate(
          controller: controller,
          child: const Scaffold(body: Center(child: Text('Unlocked vault'))),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Unlocked vault'), findsOneWidget);

    await controller.handleAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();

    expect(find.text('Unlock vault'), findsOneWidget);
    expect(find.text('Unlocked vault'), findsNothing);
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
