import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:gestor_contrasenas/app/localization/app_locale_controller.dart';
import 'package:gestor_contrasenas/core/security/biometric_auth_service.dart';
import 'package:gestor_contrasenas/core/security/master_password_service.dart';
import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/security/vault_repository.dart';
import 'package:gestor_contrasenas/core/security/vault_security_controller.dart';
import 'package:gestor_contrasenas/features/access/presentation/access_screen.dart';
import 'package:gestor_contrasenas/features/security/presentation/security_gate.dart';
import 'package:gestor_contrasenas/features/settings/presentation/settings_screen.dart';
import 'package:gestor_contrasenas/features/vault/domain/vault_item.dart';
import 'package:gestor_contrasenas/features/vault/domain/vault_summary.dart';
import 'package:gestor_contrasenas/features/vault/presentation/vault_dashboard_screen.dart';
import 'package:gestor_contrasenas/features/vault/presentation/vault_entry_detail_screen.dart';
import 'package:gestor_contrasenas/features/vault/presentation/vault_entry_editor_screen.dart';
import 'package:gestor_contrasenas/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadWindowsFont('Segoe UI', 'C:/Windows/Fonts/segoeui.ttf');
    await _loadWindowsFont('Segoe UI', 'C:/Windows/Fonts/segoeuib.ttf');
    await _loadWindowsFont('Segoe UI', 'C:/Windows/Fonts/seguisb.ttf');
    await _loadWindowsFont(
      'MaterialIcons',
      '${Platform.environment['LOCALAPPDATA']}/Pub/Cache/hosted/pub.dev/'
          'shared_preferences-2.5.4/extension/devtools/build/assets/fonts/'
          'MaterialIcons-Regular.otf',
    );
  });

  group('publication screenshots', () {
    testWidgets('01 onboarding', (tester) async {
      final controller = await _buildController(unlocked: false);
      addTearDown(controller.dispose);

      await _pumpScreen(
        tester,
        SecurityGate(controller: controller, child: const SizedBox.shrink()),
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/publication/screenshots/01-onboarding.png'),
      );
    });

    testWidgets('02 dashboard', (tester) async {
      await _pumpScreen(
        tester,
        VaultDashboardScreen(repository: _DemoVaultRepository()),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/publication/screenshots/02-dashboard.png'),
      );
    });

    testWidgets('03 search results', (tester) async {
      await _pumpScreen(
        tester,
        VaultDashboardScreen(repository: _DemoVaultRepository()),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.enterText(find.byType(TextField).first, 'vaulta');
      await tester.pump(const Duration(milliseconds: 250));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/publication/screenshots/03-search.png'),
      );
    });

    testWidgets('04 editor', (tester) async {
      await _pumpScreen(tester, const VaultEntryEditorScreen());

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/publication/screenshots/04-editor.png'),
      );
    });

    testWidgets('05 detail', (tester) async {
      await _pumpScreen(tester, VaultEntryDetailScreen(item: _demoItems.first));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/publication/screenshots/05-detail.png'),
      );
    });

    testWidgets('06 access', (tester) async {
      final controller = await _buildController(unlocked: true);
      addTearDown(controller.dispose);

      await _pumpScreen(
        tester,
        AccessScreen(
          securityController: controller,
          repository: _DemoVaultRepository(),
        ),
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/publication/screenshots/06-access.png'),
      );
    });

    testWidgets('07 settings', (tester) async {
      final controller = await _buildController(unlocked: true);
      final localeController = AppLocaleController(
        storage: _InMemorySecureStorageService(),
      );
      await localeController.initialize();
      addTearDown(controller.dispose);

      await _pumpScreen(
        tester,
        SettingsScreen(
          securityController: controller,
          localeController: localeController,
          secureStorage: _InMemorySecureStorageService(),
        ),
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/publication/screenshots/07-settings.png'),
      );
    });
  });
}

Future<void> _pumpScreen(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      theme: _screenshotTheme(Brightness.light),
      darkTheme: _screenshotTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: home,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

ThemeData _screenshotTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFB11226),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF120A0C)
        : const Color(0xFFFFF8F5),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
    ),
    fontFamily: 'Segoe UI',
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: colorScheme.primary.withValues(alpha: 0.18),
    ),
  );
}

Future<void> _loadWindowsFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

Future<VaultSecurityController> _buildController({
  required bool unlocked,
}) async {
  final controller = VaultSecurityController(
    storage: _InMemorySecureStorageService(),
    masterPasswordService: MasterPasswordService.test(),
    biometricAuthService: const _FakeBiometricAuthService(),
  );

  await controller.initialize();
  if (unlocked) {
    await controller.createMasterPassword(
      password: 'DemoStrongPass!2026',
      confirmation: 'DemoStrongPass!2026',
      enableBiometrics: false,
    );
    await controller.setIdleTimeoutSeconds(0);
  }
  return controller;
}

final _demoItems = <VaultItem>[
  VaultItem(
    id: 'vaulta',
    title: 'Vaulta Admin',
    username: 'admin@vaulta.app',
    secret: 'StrongDemoSecret!2026',
    category: VaultCategory.infrastructure,
    strengthScore: 95,
    lastUpdatedLabel: 'Actualizado ahora',
    website: 'https://vaulta.app',
    notes: 'Cuenta demo para capturas de presentacion.',
    updatedAt: DateTime(2026, 6, 10, 9),
  ),
  VaultItem(
    id: 'bank',
    title: 'Banco personal',
    username: 'finanzas@demo.app',
    secret: 'FinanceDemo!2026',
    category: VaultCategory.finance,
    strengthScore: 88,
    lastUpdatedLabel: 'Actualizado hace 1h',
    website: 'https://bank.example',
    updatedAt: DateTime(2026, 6, 10, 8),
  ),
  VaultItem(
    id: 'github',
    title: 'GitHub',
    username: 'dev@tecnodespegue.com',
    secret: 'DevTokenDemo!2026',
    category: VaultCategory.work,
    strengthScore: 82,
    lastUpdatedLabel: 'Actualizado ayer',
    notes: 'Token con permisos limitados.',
    updatedAt: DateTime(2026, 6, 9, 12),
  ),
  VaultItem(
    id: 'mail',
    title: 'Correo backup',
    username: 'backup@demo.app',
    secret: 'short',
    category: VaultCategory.personal,
    strengthScore: 32,
    lastUpdatedLabel: 'Actualizado hace 4d',
    updatedAt: DateTime(2026, 6, 6, 12),
  ),
];

class _DemoVaultRepository implements VaultRepository {
  @override
  Future<List<VaultItem>> fetchItems() async => _demoItems;

  @override
  Future<VaultSummary> fetchSummary() async {
    return const VaultSummary(
      totalItems: 4,
      weakItems: 1,
      reusedItems: 0,
      securityScore: 74,
      connectedDevices: 2,
      syncEnabled: true,
    );
  }

  @override
  Future<VaultItem?> fetchItemById(String id) async {
    for (final item in _demoItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<VaultItem> saveItem(VaultItem item) async => item;

  @override
  Future<void> deleteItem(String id) async {}
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
