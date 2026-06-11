import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:gestor_contrasenas/app/localization/app_locale_controller.dart';
import 'package:gestor_contrasenas/core/security/biometric_auth_service.dart';
import 'package:gestor_contrasenas/core/security/master_password_service.dart';
import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/security/vault_repository.dart';
import 'package:gestor_contrasenas/core/security/vault_security_controller.dart';
import 'package:gestor_contrasenas/features/home/presentation/app_shell.dart';
import 'package:gestor_contrasenas/features/vault/domain/vault_item.dart';
import 'package:gestor_contrasenas/features/vault/domain/vault_summary.dart';
import 'package:gestor_contrasenas/l10n/app_localizations.dart';

class _InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> save(String key, String value) async => _values[key] = value;
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

class _EmptyVaultRepository implements VaultRepository {
  @override
  Future<List<VaultItem>> fetchItems() async => const [];

  @override
  Future<VaultSummary> fetchSummary() async => const VaultSummary(
    totalItems: 0,
    weakItems: 0,
    reusedItems: 0,
    securityScore: 0,
    connectedDevices: 0,
    syncEnabled: false,
  );

  @override
  Future<VaultItem?> fetchItemById(String id) async => null;

  @override
  Future<VaultItem> saveItem(VaultItem item) async => item;

  @override
  Future<void> deleteItem(String id) async {}
}

void main() {
  testWidgets('AppShell shows three tabs and switches to Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _InMemorySecureStorageService();
    final controller = VaultSecurityController(
      storage: storage,
      masterPasswordService: MasterPasswordService.test(),
      biometricAuthService: const _FakeBiometricAuthService(),
    );
    await controller.initialize();
    final localeController = AppLocaleController(storage: storage);
    await localeController.initialize();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppShell(
          repository: _EmptyVaultRepository(),
          securityController: controller,
          localeController: localeController,
          secureStorage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('Access'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);

    await _disposeTree(tester);
  });
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}
