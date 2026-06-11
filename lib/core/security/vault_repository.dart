import '../../features/vault/domain/vault_item.dart';
import '../../features/vault/domain/vault_summary.dart';

/// Read/write surface for vault items. The default implementation
/// (`LocalEncryptedVaultRepository` in this same folder) talks to the
/// on-device encrypted store; tests substitute fakes.
abstract interface class VaultRepository {
  /// Returns aggregate counts (total/weak/reused items, security score,
  /// connected devices, sync state) used by the dashboard.
  Future<VaultSummary> fetchSummary();

  /// Returns the full list of items in display order.
  Future<List<VaultItem>> fetchItems();

  /// Returns the item with [id] or `null` if not present.
  Future<VaultItem?> fetchItemById(String id);

  /// Persists [item] (insert or update). Returns the canonical copy
  /// written (with any server-assigned fields normalized).
  Future<VaultItem> saveItem(VaultItem item);

  /// Removes the item with [id] from the vault (logical delete; the
  /// sync layer may keep a tombstone).
  Future<void> deleteItem(String id);
}
