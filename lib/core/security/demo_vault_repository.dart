import 'package:flutter/material.dart';

import '../../features/vault/domain/vault_item.dart';
import '../../features/vault/domain/vault_summary.dart';
import 'platform_security_plan.dart';
import 'vault_repository.dart';

class DemoVaultRepository implements VaultRepository {
  static const securityPlan = PlatformSecurityPlan(
    secureStorage: true,
    biometricUnlock: true,
    hardwareBackedKeys: true,
    notes:
        'La implementacion real debe apoyarse en Keychain/Keystore, autenticacion biometrica del sistema y una libreria criptografica auditada.',
  );

  @override
  Future<List<VaultItem>> fetchRecentItems() async {
    return [
      VaultItem(
        title: 'Figma Workspace',
        username: 'product@vaulta.app',
        category: VaultCategory.work,
        strengthScore: 96,
        lastUpdatedLabel: 'Updated 2d ago',
        icon: Icons.design_services_rounded,
        accentColor: const Color(0xFF1C6E8C),
      ),
      VaultItem(
        title: 'Mercado Pago',
        username: 'finanzas@vaulta.app',
        category: VaultCategory.finance,
        strengthScore: 88,
        lastUpdatedLabel: 'Updated today',
        icon: Icons.account_balance_wallet_rounded,
        accentColor: const Color(0xFF2D936C),
      ),
      VaultItem(
        title: 'Notion Personal',
        username: 'leo@vaulta.app',
        category: VaultCategory.personal,
        strengthScore: 72,
        lastUpdatedLabel: 'Review now',
        icon: Icons.menu_book_rounded,
        accentColor: const Color(0xFFF2C14E),
      ),
    ];
  }

  @override
  Future<VaultSummary> fetchSummary() async {
    return const VaultSummary(
      totalItems: 128,
      weakItems: 5,
      reusedItems: 2,
      securityScore: 91,
      connectedDevices: 3,
      syncEnabled: true,
    );
  }
}
