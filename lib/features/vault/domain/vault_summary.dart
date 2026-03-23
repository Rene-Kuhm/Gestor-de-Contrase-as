class VaultSummary {
  const VaultSummary({
    required this.totalItems,
    required this.weakItems,
    required this.reusedItems,
    required this.securityScore,
    required this.connectedDevices,
    required this.syncEnabled,
  });

  final int totalItems;
  final int weakItems;
  final int reusedItems;
  final int securityScore;
  final int connectedDevices;
  final bool syncEnabled;
}
