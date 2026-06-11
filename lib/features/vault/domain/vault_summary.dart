/// Aggregated metrics shown in the vault dashboard hero section.
class VaultSummary {
  const VaultSummary({
    required this.totalItems,
    required this.weakItems,
    required this.reusedItems,
    required this.securityScore,
    required this.connectedDevices,
    required this.syncEnabled,
  });

  /// Total number of entries stored in the vault.
  final int totalItems;

  /// Number of entries whose [VaultItem.strengthScore] is below the
  /// "weak" threshold.
  final int weakItems;

  /// Number of entries whose secret is shared with at least one
  /// other entry.
  final int reusedItems;

  /// Overall security score in the 0..100 range.
  final int securityScore;

  /// Number of devices currently linked to this vault via the sync
  /// service.
  final int connectedDevices;

  /// `true` if the sync service is enabled for the current account.
  final bool syncEnabled;
}
