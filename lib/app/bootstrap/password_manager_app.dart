import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gestor_contrasenas/l10n/app_localizations.dart';

import '../localization/app_locale_controller.dart';
import '../../core/security/aes_gcm_vault_crypto_service.dart';
import '../../core/security/biometric_auth_service.dart';
import '../../core/security/flutter_secure_storage_service.dart';
import '../../core/security/local_encrypted_vault_repository.dart';
import '../../core/security/master_password_service.dart';
import '../../core/security/vault_repository.dart';
import '../../core/security/vault_security_controller.dart';
import '../../core/sync/device_registration_service.dart';
import '../../core/sync/device_sync_bootstrap.dart';
import '../../features/home/presentation/app_shell.dart';
import '../../features/security/presentation/security_gate.dart';
import '../theme/app_theme.dart';

Future<void> runPasswordManagerApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = FlutterSecureStorageService();
  final localeController = AppLocaleController(storage: storage);
  late final VaultSecurityController securityController;
  final repository = LocalEncryptedVaultRepository(
    storage: storage,
    cryptoService: AesGcmVaultCryptoService(),
    readSession: () => securityController.vaultSession,
  );
  securityController = VaultSecurityController(
    storage: storage,
    masterPasswordService: MasterPasswordService(),
    biometricAuthService: LocalBiometricAuthService(),
    rekeyEntries: repository.rekeyEntries,
  );

  await securityController.initialize();
  await localeController.initialize();

  final deviceSyncLifecycle = await buildDeviceSyncLifecycle(storage: storage);

  runApp(
    PasswordManagerApp(
      repository: repository,
      securityController: securityController,
      localeController: localeController,
      deviceSyncLifecycle: deviceSyncLifecycle,
    ),
  );
}

class PasswordManagerApp extends StatelessWidget {
  const PasswordManagerApp({
    super.key,
    required this.repository,
    required this.securityController,
    required this.localeController,
    this.deviceSyncLifecycle,
  });

  final VaultRepository repository;
  final VaultSecurityController securityController;
  final AppLocaleController localeController;
  final DeviceSyncLifecycle? deviceSyncLifecycle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: localeController,
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          locale: localeController.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SecurityGate(
            controller: securityController,
            deviceSyncLifecycle: deviceSyncLifecycle,
            child: AppShell(
              repository: repository,
              securityController: securityController,
              localeController: localeController,
            ),
          ),
        );
      },
    );
  }
}
