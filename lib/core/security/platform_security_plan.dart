class PlatformSecurityPlan {
  const PlatformSecurityPlan({
    required this.secureStorage,
    required this.biometricUnlock,
    required this.hardwareBackedKeys,
    required this.vaultEncryptionReady,
    required this.notes,
  });

  final bool secureStorage;
  final bool biometricUnlock;
  final bool hardwareBackedKeys;
  final bool vaultEncryptionReady;
  final String notes;
}
