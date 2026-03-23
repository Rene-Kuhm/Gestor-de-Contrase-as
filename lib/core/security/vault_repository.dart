import '../../features/vault/domain/vault_item.dart';
import '../../features/vault/domain/vault_summary.dart';

abstract interface class VaultRepository {
  Future<VaultSummary> fetchSummary();

  Future<List<VaultItem>> fetchRecentItems();
}
