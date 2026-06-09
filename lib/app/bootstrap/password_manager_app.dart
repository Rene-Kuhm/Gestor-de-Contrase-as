import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gestor_contrasenas/l10n/app_localizations.dart';

import '../localization/app_locale_controller.dart';
import '../../core/security/aes_gcm_vault_crypto_service.dart';
import '../../core/security/android_keystore_envelope_key_provider.dart';
import '../../core/security/biometric_auth_service.dart';
import '../../core/security/biometric_key_envelope_service.dart';
import '../../core/security/biometric_unlock_service.dart';
import '../../core/security/flutter_secure_storage_service.dart';
import '../../core/security/local_encrypted_vault_repository.dart';
import '../../core/security/master_password_service.dart';
import '../../core/security/vault_repository.dart';
import '../../core/security/vault_security_controller.dart';
import '../../core/sync/device_registration_repository.dart';
import '../../core/sync/device_registration_service.dart';
import '../../core/sync/device_sync_bootstrap.dart';
import '../../core/sync/local_vault_mutation.dart';
import '../../features/home/presentation/app_shell.dart';
import '../../features/security/presentation/security_gate.dart';
import '../theme/app_theme.dart';

Future<void> runPasswordManagerApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = FlutterSecureStorageService();
  final localeController = AppLocaleController(storage: storage);
  final mutationSink = RelayLocalVaultMutationSink();
  late final VaultSecurityController securityController;
  final repository = LocalEncryptedVaultRepository(
    storage: storage,
    cryptoService: AesGcmVaultCryptoService(),
    readSession: () => securityController.vaultSession,
    mutationSink: mutationSink,
  );
  final envelopeService = BiometricKeyEnvelopeService(storage: storage);
  final envelopeKeyProvider = _buildEnvelopeKeyProvider(storage: storage);
  final biometricUnlockService = BiometricUnlockService(
    storage: storage,
    biometricAuthService: LocalBiometricAuthService(),
    envelopeService: envelopeService,
    envelopeKeyProvider: envelopeKeyProvider,
  );
  securityController = VaultSecurityController(
    storage: storage,
    masterPasswordService: MasterPasswordService(),
    biometricAuthService: LocalBiometricAuthService(),
    rekeyEntries: repository.rekeyEntries,
    biometricEnvelopeService: envelopeService,
    biometricUnlockService: biometricUnlockService,
  );

  await securityController.initialize();
  await localeController.initialize();

  final deviceSyncLifecycle = await buildDeviceSyncLifecycle(
    storage: storage,
    vaultRepository: repository,
    mutationSink: mutationSink,
    onCurrentDeviceRevoked: (DeviceAccessStatus status) {
      return securityController.lock(reason: status.userFacingReason());
    },
  );

  runApp(
    PasswordManagerApp(
      repository: repository,
      securityController: securityController,
      localeController: localeController,
      deviceSyncLifecycle: deviceSyncLifecycle,
    ),
  );
}

/// On Android we use the hardware-backed KeyStore provider. On every
/// other target we fall back to a no-op provider that always reports
/// "no envelope key", which surfaces a clean "biometrics not
/// available" message instead of crashing.
///
/// Tests that don't want to involve the platform channel can override
/// the provider in their own bootstrap.
BiometricEnvelopeKeyProvider _buildEnvelopeKeyProvider({
  required dynamic storage,
}) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidKeystoreEnvelopeKeyProvider(
      storage: storage as FlutterSecureStorageService,
    );
  }
  // The unlock service replaces this with its own no-op default if
  // we pass null, so this branch is only here to make the intent
  // explicit in the source.
  return const _NullEnvelopeKeyProvider();
}

class _NullEnvelopeKeyProvider implements BiometricEnvelopeKeyProvider {
  const _NullEnvelopeKeyProvider();

  @override
  Future<SecretKey?> acquireEnvelopeKey() async => null;

  @override
  Future<SecretKey?> releaseEnvelopeKey() async => null;
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
              conflictResolver: deviceSyncLifecycle?.conflictResolver,
              revocationService: deviceSyncLifecycle?.revocationService,
            ),
          ),
        );
      },
    );
  }
}
