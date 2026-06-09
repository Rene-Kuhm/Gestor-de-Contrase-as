import 'local_remote_vault_store.dart';
import 'remote_vault_sync_repository.dart';
import 'sync_conflict.dart';
import 'sync_runtime_hardening.dart';

class SyncConflictResolveResult {
  const SyncConflictResolveResult({required this.ok, required this.message});

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
      syncDebugPrint('[sync][conflict] resolve failed: unauthenticated user.');
      return const SyncConflictResolveResult(
        ok: false,
        message:
            'Sync conflict could not be resolved because the user is not authenticated.',
      );
    }

    final conflicts = await _localStore.readPendingConflicts(userId: userId);
    final conflictIndex = conflicts.indexWhere((item) => item.id == conflictId);
    if (conflictIndex == -1) {
      syncDebugPrint(
        '[sync][conflict] conflict=$conflictId missing before resolve.',
      );
      return const SyncConflictResolveResult(
        ok: false,
        message: 'Sync conflict is already resolved or missing.',
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
      syncDebugPrint(
        '[sync][conflict] conflict=${conflict.id} resolved as keep_remote.',
      );
      return const SyncConflictResolveResult(
        ok: true,
        message:
            'Remote version accepted. Local mutation was discarded safely.',
      );
    }

    if (queueIndex == -1) {
      syncDebugPrint(
        '[sync][conflict] conflict=${conflict.id} missing queue mutation.',
      );
      return const SyncConflictResolveResult(
        ok: false,
        message:
            'Sync conflict could not be retried because the local mutation is missing.',
      );
    }

    final queueItem = queue[queueIndex];
    final remoteVersion =
        conflict.currentVersion ?? conflict.remoteSnapshot?.version;
    if (queueItem.kind == PushQueueOperationKind.delete &&
        remoteVersion == null) {
      syncDebugPrint(
        '[sync][conflict] conflict=${conflict.id} delete retry missing remote version.',
      );
      return const SyncConflictResolveResult(
        ok: false,
        message: 'Delete conflict requires a remote version before retrying.',
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
      gcmTag: queueItem.gcmTag,
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
    syncDebugPrint(
      '[sync][conflict] conflict=${conflict.id} resolved as keep_local.',
    );

    return const SyncConflictResolveResult(
      ok: true,
      message:
          'Local version kept. Mutation re-queued with remote base version.',
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
