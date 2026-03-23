import 'package:flutter/material.dart';

import '../../core/security/aes_gcm_vault_crypto_service.dart';
import '../../core/security/biometric_auth_service.dart';
import '../../core/security/flutter_secure_storage_service.dart';
import '../../core/security/local_encrypted_vault_repository.dart';
import '../../core/security/master_password_service.dart';
import '../../core/security/vault_repository.dart';
import '../../core/security/vault_security_controller.dart';
import '../../features/home/presentation/app_shell.dart';
import '../../features/security/presentation/security_gate.dart';
import '../theme/app_theme.dart';

Future<void> runPasswordManagerApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = FlutterSecureStorageService();
  final securityController = VaultSecurityController(
    storage: storage,
    masterPasswordService: MasterPasswordService(),
    biometricAuthService: LocalBiometricAuthService(),
  );
  final repository = LocalEncryptedVaultRepository(
    storage: storage,
    cryptoService: AesGcmVaultCryptoService(),
    readSession: () => securityController.vaultSession,
  );

  await securityController.initialize();

  runApp(
    PasswordManagerApp(
      repository: repository,
      securityController: securityController,
    ),
  );
}

class PasswordManagerApp extends StatelessWidget {
  const PasswordManagerApp({
    super.key,
    required this.repository,
    required this.securityController,
  });

  final VaultRepository repository;
  final VaultSecurityController securityController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaulta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: SecurityGate(
        controller: securityController,
        child: AppShell(
          repository: repository,
          securityController: securityController,
        ),
      ),
    );
  }
}
