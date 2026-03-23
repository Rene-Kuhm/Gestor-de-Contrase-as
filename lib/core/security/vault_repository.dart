import '../../features/vault/domain/vault_item.dart';
import '../../features/vault/domain/vault_summary.dart';

abstract interface class VaultRepository {
  Future<VaultSummary> fetchSummary();

  Future<List<VaultItem>> fetchItems();

  Future<VaultItem?> fetchItemById(String id);

  Future<VaultItem> saveItem(VaultItem item);

  Future<void> deleteItem(String id);
}
