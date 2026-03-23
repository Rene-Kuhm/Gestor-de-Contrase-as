import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:gestor_contrasenas/app/bootstrap/password_manager_app.dart';
import 'package:gestor_contrasenas/core/security/aes_gcm_vault_crypto_service.dart';
import 'package:gestor_contrasenas/core/security/biometric_auth_service.dart';
import 'package:gestor_contrasenas/core/security/local_encrypted_vault_repository.dart';
import 'package:gestor_contrasenas/core/security/master_password_service.dart';
import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/security/vault_security_controller.dart';

void main() {
  testWidgets('shows onboarding when no master password exists', (
    tester,
  ) async {
    final controller = VaultSecurityController(
      storage: _InMemorySecureStorageService(),
      masterPasswordService: MasterPasswordService(),
      biometricAuthService: const _FakeBiometricAuthService(),
    );
    await controller.initialize();

    await tester.pumpWidget(
      PasswordManagerApp(
        repository: LocalEncryptedVaultRepository(
          storage: _InMemorySecureStorageService(),
          cryptoService: AesGcmVaultCryptoService(),
          readSession: () => controller.vaultSession,
        ),
        securityController: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vaulta'), findsOneWidget);
    expect(find.text('Create secure vault access'), findsOneWidget);
    expect(find.text('Onboarding seguro'), findsOneWidget);
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
