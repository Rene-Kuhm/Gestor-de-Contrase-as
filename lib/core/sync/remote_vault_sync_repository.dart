import 'remote_vault_blob_change.dart';

abstract interface class RemoteVaultSyncRepository {
  Future<String?> readCurrentUserId();

  Future<List<RemoteVaultBlobChange>> fetchChangesSince({
    required int afterOpId,
    int limit,
  });
}
