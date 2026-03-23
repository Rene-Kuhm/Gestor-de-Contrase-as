class PlatformSecurityPlan {
  const PlatformSecurityPlan({
    required this.secureStorage,
    required this.biometricUnlock,
    required this.hardwareBackedKeys,
    required this.notes,
  });

  final bool secureStorage;
  final bool biometricUnlock;
  final bool hardwareBackedKeys;
  final String notes;
}
