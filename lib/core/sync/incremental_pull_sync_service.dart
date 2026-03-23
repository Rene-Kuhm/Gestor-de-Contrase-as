import 'local_remote_vault_store.dart';
import 'remote_vault_sync_repository.dart';

class IncrementalPullSyncService {
  IncrementalPullSyncService({
    required RemoteVaultSyncRepository repository,
    required LocalRemoteVaultStore localStore,
    required Future<String> Function() readDeviceId,
    this.batchSize = 200,
    this.throttleInterval = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : _repository = repository,
       _localStore = localStore,
       _readDeviceId = readDeviceId,
       _now = now ?? DateTime.now;

  final RemoteVaultSyncRepository _repository;
  final LocalRemoteVaultStore _localStore;
  final Future<String> Function() _readDeviceId;
  final int batchSize;
  final Duration throttleInterval;
  final DateTime Function() _now;

  Future<void> onSessionStarted() async {
    await _runPull(force: false);
  }

  Future<void> onAppResumed() async {
    await _runPull(force: false);
  }

  Future<void> _runPull({required bool force}) async {
    final userId = await _repository.readCurrentUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final deviceId = await _readDeviceId();
    if (deviceId.isEmpty) {
      return;
    }

    if (!force) {
      final lastPullAt = await _localStore.readLastPullAt(
        userId: userId,
        deviceId: deviceId,
      );
      if (lastPullAt != null && _now().difference(lastPullAt) < throttleInterval) {
        return;
      }
    }

    var cursor = await _localStore.readCursor(userId: userId, deviceId: deviceId);

    while (true) {
      final changes = await _repository.fetchChangesSince(
        afterOpId: cursor,
        limit: batchSize,
      );
      if (changes.isEmpty) {
        break;
      }

      cursor = changes.last.opCursor;
      await _localStore.applyChanges(
        userId: userId,
        deviceId: deviceId,
        changes: changes,
        newCursor: cursor,
      );

      if (changes.length < batchSize) {
        break;
      }
    }

    await _localStore.saveLastPullAt(
      userId: userId,
      deviceId: deviceId,
      lastPullAt: _now().toUtc(),
    );
  }
}
