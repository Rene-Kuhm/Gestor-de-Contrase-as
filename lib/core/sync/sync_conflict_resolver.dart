import 'local_remote_vault_store.dart';
import 'remote_vault_sync_repository.dart';
import 'sync_conflict.dart';

class SyncConflictResolveResult {
  const SyncConflictResolveResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}

class SyncConflictResolver {
  SyncConflictResolver({
    required RemoteVaultSyncRepository repository,
    required LocalRemoteVaultStore localStore,
    Future<void> Function()? triggerPushSync,
    DateTime Function()? now,
  }) : _repository = repository,
       _localStore = localStore,
       _triggerPushSync = triggerPushSync,
       _now = now ?? DateTime.now;

  final RemoteVaultSyncRepository _repository;
  final LocalRemoteVaultStore _localStore;
  final Future<void> Function()? _triggerPushSync;
  final DateTime Function() _now;

  Future<List<SyncConflictRecord>> readPendingConflicts() async {
    final userId = await _readUserId();
    if (userId == null) {
      return const [];
    }

    final conflicts = await _localStore.readPendingConflicts(userId: userId);
    conflicts.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return conflicts;
  }

  Future<SyncConflictResolveResult> resolve({
    required String conflictId,
    required SyncConflictResolution resolution,
  }) async {
    final userId = await _readUserId();
    if (userId == null) {
      return const SyncConflictResolveResult(
        ok: false,
        message: 'No authenticated user for conflict resolution.',
      );
    }

    final conflicts = await _localStore.readPendingConflicts(userId: userId);
    final conflictIndex = conflicts.indexWhere((item) => item.id == conflictId);
    if (conflictIndex == -1) {
      return const SyncConflictResolveResult(
        ok: false,
        message: 'Conflict was already resolved or missing.',
      );
    }

    final conflict = conflicts[conflictIndex];
    final queue = await _localStore.readPushQueue(userId: userId);
    final queueIndex = queue.indexWhere((item) => item.opId == conflict.opId);

    if (resolution == SyncConflictResolution.keepRemote) {
      if (queueIndex != -1) {
        queue.removeAt(queueIndex);
        await _localStore.savePushQueue(userId: userId, items: queue);
      }
      await _localStore.removePendingConflict(
        userId: userId,
        conflictId: conflict.id,
      );
      return const SyncConflictResolveResult(
        ok: true,
        message: 'Remote version accepted. Local pending mutation was discarded.',
      );
    }

    if (queueIndex == -1) {
      return const SyncConflictResolveResult(
        ok: false,
        message: 'Local mutation no longer exists in queue.',
      );
    }

    final queueItem = queue[queueIndex];
    final remoteVersion = conflict.currentVersion ?? conflict.remoteSnapshot?.version;
    if (queueItem.kind == PushQueueOperationKind.delete && remoteVersion == null) {
      return const SyncConflictResolveResult(
        ok: false,
        message: 'Delete conflict needs remote version to retry safely.',
      );
    }

    queue[queueIndex] = PushQueueItem(
      opId: queueItem.opId,
      localRecordId: queueItem.localRecordId,
      remoteRecordId: queueItem.remoteRecordId,
      kind: queueItem.kind,
      status: PushQueueStatus.pending,
      createdAt: queueItem.createdAt,
      updatedAt: _now().toUtc(),
      expectedVersion: remoteVersion,
      ciphertext: queueItem.ciphertext,
      nonce: queueItem.nonce,
      aad: queueItem.aad,
      keyVersion: queueItem.keyVersion,
      idempotencyKey: null,
      attemptCount: queueItem.attemptCount,
      retryCount: 0,
      nextAttemptAt: null,
      lastResultCode: 'manual_keep_local',
      lastMessage: 'Retry scheduled after manual conflict resolution.',
    );

    await _localStore.savePushQueue(userId: userId, items: queue);
    await _localStore.removePendingConflict(
      userId: userId,
      conflictId: conflict.id,
    );
    await _triggerPushSync?.call();

    return const SyncConflictResolveResult(
      ok: true,
      message: 'Local version kept. Mutation re-queued with updated base version.',
    );
  }

  Future<String?> _readUserId() async {
    final userId = await _repository.readCurrentUserId();
    if (userId == null || userId.isEmpty) {
      return null;
    }

    return userId;
  }
}
