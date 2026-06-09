import 'local_remote_vault_store.dart';
import 'remote_vault_blob_change.dart';
import 'remote_vault_sync_repository.dart';
import 'sync_runtime_hardening.dart';

class IncrementalPullSyncService {
  IncrementalPullSyncService({
    required RemoteVaultSyncRepository repository,
    required LocalRemoteVaultStore localStore,
    required Future<String> Function() readDeviceId,
    this.batchSize = 200,
    this.maxRetryAttempts = 2,
    this.baseRetryDelay = const Duration(seconds: 1),
    this.throttleInterval = const Duration(minutes: 2),
    this.diagnosticsHook,
    Future<void> Function(Iterable<RemoteVaultBlobSnapshot> snapshots)?
    applyLocalSnapshots,
    Future<void> Function(Duration delay)? delay,
    DateTime Function()? now,
  }) : _repository = repository,
       _localStore = localStore,
       _readDeviceId = readDeviceId,
       _applyLocalSnapshots = applyLocalSnapshots,
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  final RemoteVaultSyncRepository _repository;
  final LocalRemoteVaultStore _localStore;
  final Future<String> Function() _readDeviceId;
  final int batchSize;
  final int maxRetryAttempts;
  final Duration baseRetryDelay;
  final Duration throttleInterval;
  final SyncDiagnosticsHook? diagnosticsHook;
  final Future<void> Function(Iterable<RemoteVaultBlobSnapshot> snapshots)?
  _applyLocalSnapshots;
  final Future<void> Function(Duration delay) _delay;
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
      if (lastPullAt != null &&
          _now().difference(lastPullAt) < throttleInterval) {
        return;
      }
    }

    var cursor = await _localStore.readCursor(
      userId: userId,
      deviceId: deviceId,
    );

    while (true) {
      final changes = await _fetchWithRetry(afterOpId: cursor);
      if (changes == null) {
        return;
      }

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
      final applyLocalSnapshots = _applyLocalSnapshots;
      if (applyLocalSnapshots != null) {
        final snapshots = await _resolveSnapshotIds(
          userId: userId,
          changes: changes,
        );
        await applyLocalSnapshots(snapshots);
      }

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

  Future<List<RemoteVaultBlobSnapshot>> _resolveSnapshotIds({
    required String userId,
    required List<RemoteVaultBlobChange> changes,
  }) async {
    final resolved = <RemoteVaultBlobSnapshot>[];
    for (final change in changes) {
      final localId = await _localStore.resolveLocalRecordId(
        userId: userId,
        remoteRecordId: change.recordId,
      );
      final base = RemoteVaultBlobSnapshot.fromChange(change);
      if (localId == base.recordId) {
        resolved.add(base);
      } else {
        resolved.add(
          RemoteVaultBlobSnapshot(
            recordId: localId,
            version: base.version,
            keyVersion: base.keyVersion,
            ciphertext: base.ciphertext,
            nonce: base.nonce,
            gcmTag: base.gcmTag,
            deletedAt: base.deletedAt,
            updatedAt: base.updatedAt,
          ),
        );
      }
    }

    return resolved;
  }

  Future<List<RemoteVaultBlobChange>?> _fetchWithRetry({
    required int afterOpId,
  }) async {
    if (maxRetryAttempts < 1) {
      return null;
    }

    Object? lastError;
    for (var attempt = 1; attempt <= maxRetryAttempts; attempt += 1) {
      try {
        return await _repository.fetchChangesSince(
          afterOpId: afterOpId,
          limit: batchSize,
        );
      } catch (error) {
        lastError = error;
        final disposition = classifySyncError(error);
        final code = syncErrorCode(error);
        final message = syncMessageForCode(
          code,
          fallback:
              'No se pudo obtener cambios remotos para el cursor $afterOpId.',
        );
        final retriable = disposition == SyncErrorDisposition.transient;
        emitSyncDiagnostic(
          scope: 'pull',
          operation: 'fetch_changes',
          code: code,
          message: message,
          retriable: retriable,
          timestamp: _now(),
          hook: diagnosticsHook,
          attempt: attempt,
          maxAttempts: maxRetryAttempts,
          error: error,
          metadata: {'afterOpId': afterOpId},
        );
        syncDebugPrint(
          '[sync][pull] fetch after=$afterOpId attempt=$attempt/$maxRetryAttempts failed: $error',
        );
        if (attempt >= maxRetryAttempts || !retriable) {
          break;
        }

        final delayMs = baseRetryDelay.inMilliseconds * (1 << (attempt - 1));
        await _delay(Duration(milliseconds: delayMs));
      }
    }

    syncDebugPrint(
      '[sync][pull] aborting pull after $maxRetryAttempts attempts (after=$afterOpId): ${lastError ?? 'unknown error'}',
    );
    return null;
  }
}
