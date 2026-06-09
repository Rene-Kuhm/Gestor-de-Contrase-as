import 'package:uuid/uuid.dart';

import 'local_remote_vault_store.dart';
import 'local_vault_mutation.dart';
import 'remote_vault_blob_change.dart';
import 'remote_vault_sync_repository.dart';
import 'sync_conflict.dart';
import 'sync_runtime_hardening.dart';

class IncrementalPushSyncService implements LocalVaultMutationSink {
  IncrementalPushSyncService({
    required RemoteVaultSyncRepository repository,
    required LocalRemoteVaultStore localStore,
    required Future<String> Function() readDeviceId,
    Uuid? uuid,
    this.maxItemsPerRun = 20,
    this.baseBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(minutes: 2),
    this.diagnosticsHook,
    DateTime Function()? now,
  }) : _repository = repository,
       _localStore = localStore,
       _readDeviceId = readDeviceId,
       _uuid = uuid ?? const Uuid(),
       _now = now ?? DateTime.now;

  final RemoteVaultSyncRepository _repository;
  final LocalRemoteVaultStore _localStore;
  final Future<String> Function() _readDeviceId;
  final Uuid _uuid;
  final int maxItemsPerRun;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final SyncDiagnosticsHook? diagnosticsHook;
  final DateTime Function() _now;

  bool _running = false;
  bool _rerunRequested = false;

  @override
  Future<void> onLocalMutation(LocalVaultMutation mutation) async {
    final userId = await _repository.readCurrentUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final remoteRecordId = _remoteRecordIdFor(
      userId: userId,
      localRecordId: mutation.localRecordId,
    );
    await _localStore.saveRecordIdMapping(
      userId: userId,
      localRecordId: mutation.localRecordId,
      remoteRecordId: remoteRecordId,
    );
    await _localStore.enqueuePushMutation(
      userId: userId,
      item: PushQueueItem.fromMutation(
        opId: _uuid.v4(),
        remoteRecordId: remoteRecordId,
        mutation: mutation,
      ),
    );
    await _triggerSync();
  }

  Future<void> onSessionStarted() async {
    await _triggerSync();
  }

  Future<void> onAppResumed() async {
    await _triggerSync();
  }

  Future<void> runNow() async {
    await _triggerSync();
  }

  Future<void> _triggerSync() async {
    if (_running) {
      _rerunRequested = true;
      return;
    }

    _running = true;
    try {
      do {
        _rerunRequested = false;
        await _runOnce();
      } while (_rerunRequested);
    } finally {
      _running = false;
    }
  }

  Future<void> _runOnce() async {
    final userId = await _repository.readCurrentUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final deviceId = await _readDeviceId();
    if (deviceId.isEmpty) {
      return;
    }

    final queue = await _localStore.readPushQueue(userId: userId);
    if (queue.isEmpty) {
      return;
    }

    final now = _now().toUtc();
    var processed = 0;
    var index = 0;
    while (index < queue.length && processed < maxItemsPerRun) {
      final item = queue[index];
      if (!_isDispatchable(item, now: now)) {
        index += 1;
        continue;
      }

      var prepared = await _prepareForDispatch(userId: userId, item: item);
      if (prepared.status == PushQueueStatus.failed) {
        queue[index] = prepared;
        processed += 1;
        index += 1;
        continue;
      }

      queue[index] = prepared;
      final result = await _dispatch(
        userId: userId,
        deviceId: deviceId,
        item: prepared,
      );
      if (result.removeFromQueue) {
        queue.removeAt(index);
      } else {
        queue[index] = result.item;
        index += 1;
      }

      if (result.appliedVersion != null) {
        await _updateSnapshotFromResult(
          userId: userId,
          item: prepared,
          appliedVersion: result.appliedVersion!,
          deletedAt: result.deletedAt,
        );
      }

      processed += 1;
    }

    await _localStore.savePushQueue(userId: userId, items: queue);
  }

  bool _isDispatchable(PushQueueItem item, {required DateTime now}) {
    if (item.status == PushQueueStatus.failed ||
        item.status == PushQueueStatus.conflict) {
      return false;
    }

    final nextAttemptAt = item.nextAttemptAt;
    if (nextAttemptAt != null && now.isBefore(nextAttemptAt)) {
      return false;
    }

    return true;
  }

  Future<PushQueueItem> _prepareForDispatch({
    required String userId,
    required PushQueueItem item,
  }) async {
    final updatedAt = _now().toUtc();
    var expectedVersion = item.expectedVersion;
    if (expectedVersion == null) {
      final snapshot = await _localStore.readSnapshot(
        userId: userId,
        recordId: item.remoteRecordId,
      );
      expectedVersion = snapshot?.version;
    }

    if (item.kind == PushQueueOperationKind.delete && expectedVersion == null) {
      return item.copyWith(
        status: PushQueueStatus.failed,
        expectedVersion: expectedVersion,
        lastResultCode: 'local_missing_expected_version',
        lastMessage: 'Delete requires known remote version.',
        updatedAt: updatedAt,
      );
    }

    if (item.idempotencyKey == null || item.idempotencyKey!.isEmpty) {
      return item.copyWith(
        status: PushQueueStatus.inFlight,
        expectedVersion: expectedVersion,
        idempotencyKey: _uuid.v4(),
        attemptCount: item.attemptCount + 1,
        retryCount: 0,
        nextAttemptAt: null,
        updatedAt: updatedAt,
      );
    }

    return item.copyWith(
      status: PushQueueStatus.inFlight,
      expectedVersion: expectedVersion,
      nextAttemptAt: null,
      updatedAt: updatedAt,
    );
  }

  Future<_DispatchResult> _dispatch({
    required String userId,
    required String deviceId,
    required PushQueueItem item,
  }) async {
    try {
      final response = await _sendToRemote(deviceId: deviceId, item: item);
      return _interpretResponse(userId: userId, item: item, response: response);
    } catch (error) {
      final disposition = classifySyncError(error);
      final code = syncErrorCode(error);
      final message = syncMessageForCode(
        code,
        fallback: 'Push failed before receiving RPC result.',
      );
      if (disposition == SyncErrorDisposition.definitive) {
        emitSyncDiagnostic(
          scope: 'push',
          operation: 'dispatch',
          code: code,
          message: message,
          retriable: false,
          timestamp: _now(),
          hook: diagnosticsHook,
          error: error,
        );
        return _DispatchResult(
          item: item.copyWith(
            status: PushQueueStatus.failed,
            lastResultCode: code,
            lastMessage: message,
            nextAttemptAt: null,
            updatedAt: _now().toUtc(),
          ),
          removeFromQueue: false,
        );
      }

      final retryCount = item.retryCount + 1;
      emitSyncDiagnostic(
        scope: 'push',
        operation: 'dispatch',
        code: code,
        message: message,
        retriable: true,
        timestamp: _now(),
        hook: diagnosticsHook,
        attempt: retryCount,
        error: error,
      );
      return _DispatchResult(
        item: item.copyWith(
          status: PushQueueStatus.retry,
          retryCount: retryCount,
          nextAttemptAt: _now().toUtc().add(_backoffFor(retryCount)),
          lastResultCode: code,
          lastMessage: message,
          updatedAt: _now().toUtc(),
        ),
        removeFromQueue: false,
      );
    }
  }

  Future<RemoteVaultPushResult> _sendToRemote({
    required String deviceId,
    required PushQueueItem item,
  }) {
    final idempotencyKey = item.idempotencyKey;
    if (idempotencyKey == null || idempotencyKey.isEmpty) {
      throw StateError('Missing idempotency key for in-flight item.');
    }

    return switch (item.kind) {
      PushQueueOperationKind.upsert => _repository.pushUpsertBlob(
        deviceId: deviceId,
        idempotencyKey: idempotencyKey,
        recordId: item.remoteRecordId,
        expectedVersion: item.expectedVersion,
        ciphertext: item.ciphertext ?? '',
        nonce: item.nonce ?? '',
        gcmTag: item.gcmTag,
        keyVersion: item.keyVersion ?? 1,
      ),
      PushQueueOperationKind.delete => _repository.pushDeleteBlob(
        deviceId: deviceId,
        idempotencyKey: idempotencyKey,
        recordId: item.remoteRecordId,
        expectedVersion: item.expectedVersion ?? -1,
      ),
    };
  }

  Future<_DispatchResult> _interpretResponse({
    required String userId,
    required PushQueueItem item,
    required RemoteVaultPushResult response,
  }) async {
    final updatedAt = _now().toUtc();
    if (response.code == RemoteVaultPushResultCode.applied ||
        response.code == RemoteVaultPushResultCode.idempotentReplay) {
      return _DispatchResult(
        item: item,
        removeFromQueue: true,
        appliedVersion: response.appliedVersion ?? response.currentVersion,
        deletedAt: response.deletedAt,
      );
    }

    if (response.code == RemoteVaultPushResultCode.casConflict) {
      await _registerConflict(userId: userId, item: item, response: response);
      final code = SyncStatusCodes.casConflict;
      final message = syncMessageForCode(code, fallback: response.message);
      emitSyncDiagnostic(
        scope: 'push',
        operation: 'dispatch',
        code: code,
        message: message,
        retriable: false,
        timestamp: _now(),
        hook: diagnosticsHook,
      );
      return _DispatchResult(
        item: item.copyWith(
          status: PushQueueStatus.conflict,
          lastResultCode: code,
          lastMessage: message,
          nextAttemptAt: null,
          updatedAt: updatedAt,
        ),
        removeFromQueue: false,
      );
    }

    if (response.code == RemoteVaultPushResultCode.idempotencyMismatch) {
      final code = SyncStatusCodes.idempotencyMismatch;
      final message = syncMessageForCode(code, fallback: response.message);
      emitSyncDiagnostic(
        scope: 'push',
        operation: 'dispatch',
        code: code,
        message: message,
        retriable: false,
        timestamp: _now(),
        hook: diagnosticsHook,
      );
      return _DispatchResult(
        item: item.copyWith(
          status: PushQueueStatus.failed,
          lastResultCode: code,
          lastMessage: message,
          nextAttemptAt: null,
          updatedAt: updatedAt,
        ),
        removeFromQueue: false,
      );
    }

    final unknownCode = _codeForUnknownResponse(response);
    final unknownMessage = syncMessageForCode(
      unknownCode,
      fallback: response.message,
    );
    if (unknownCode == SyncStatusCodes.revokedSessionOrDevice) {
      emitSyncDiagnostic(
        scope: 'push',
        operation: 'dispatch',
        code: unknownCode,
        message: unknownMessage,
        retriable: false,
        timestamp: _now(),
        hook: diagnosticsHook,
      );
      return _DispatchResult(
        item: item.copyWith(
          status: PushQueueStatus.failed,
          lastResultCode: unknownCode,
          lastMessage: unknownMessage,
          nextAttemptAt: null,
          updatedAt: updatedAt,
        ),
        removeFromQueue: false,
      );
    }

    final retryCount = item.retryCount + 1;
    emitSyncDiagnostic(
      scope: 'push',
      operation: 'dispatch',
      code: unknownCode,
      message: unknownMessage,
      retriable: true,
      timestamp: _now(),
      hook: diagnosticsHook,
      attempt: retryCount,
    );
    return _DispatchResult(
      item: item.copyWith(
        status: PushQueueStatus.retry,
        retryCount: retryCount,
        nextAttemptAt: _now().toUtc().add(_backoffFor(retryCount)),
        lastResultCode: unknownCode,
        lastMessage: unknownMessage,
        updatedAt: updatedAt,
      ),
      removeFromQueue: false,
    );
  }

  String _codeForUnknownResponse(RemoteVaultPushResult response) {
    final message = (response.message ?? '').toLowerCase();
    if (message.contains('revoked')) {
      return SyncStatusCodes.revokedSessionOrDevice;
    }
    if (message.contains('offline') || message.contains('network')) {
      return SyncStatusCodes.offlineNetworkError;
    }
    return SyncStatusCodes.unknown;
  }

  Future<void> _registerConflict({
    required String userId,
    required PushQueueItem item,
    required RemoteVaultPushResult response,
  }) async {
    final now = _now().toUtc();
    final snapshot = await _localStore.readSnapshot(
      userId: userId,
      recordId: item.remoteRecordId,
    );

    await _localStore.upsertPendingConflict(
      userId: userId,
      conflict: SyncConflictRecord(
        id: _uuid.v4(),
        opId: item.opId,
        localRecordId: item.localRecordId,
        remoteRecordId: item.remoteRecordId,
        kind: item.kind == PushQueueOperationKind.upsert
            ? SyncConflictOperationKind.upsert
            : SyncConflictOperationKind.delete,
        createdAt: now,
        updatedAt: now,
        lastResultCode: SyncStatusCodes.casConflict,
        message: syncMessageForCode(
          SyncStatusCodes.casConflict,
          fallback: response.message,
        ),
        expectedVersion: item.expectedVersion,
        currentVersion: response.currentVersion,
        localSnapshot: SyncConflictSnapshot(
          version: item.expectedVersion,
          keyVersion: item.keyVersion,
          ciphertext: item.ciphertext,
          nonce: item.nonce,
          gcmTag: item.gcmTag,
          updatedAt: item.updatedAt,
        ),
        remoteSnapshot: snapshot == null
            ? SyncConflictSnapshot(
                version: response.currentVersion,
                updatedAt: now,
              )
            : SyncConflictSnapshot(
                version: response.currentVersion ?? snapshot.version,
                keyVersion: snapshot.keyVersion,
                ciphertext: snapshot.ciphertext,
                nonce: snapshot.nonce,
                gcmTag: snapshot.gcmTag,
                deletedAt: snapshot.deletedAt,
                updatedAt: snapshot.updatedAt,
              ),
      ),
    );
  }

  Future<void> _updateSnapshotFromResult({
    required String userId,
    required PushQueueItem item,
    required int appliedVersion,
    required DateTime? deletedAt,
  }) {
    return _localStore.saveSnapshot(
      userId: userId,
      snapshot: RemoteVaultBlobSnapshot(
        recordId: item.remoteRecordId,
        version: appliedVersion,
        keyVersion: item.keyVersion ?? 1,
        ciphertext: deletedAt == null ? item.ciphertext : null,
        nonce: deletedAt == null ? item.nonce : null,
        gcmTag: deletedAt == null ? item.gcmTag : null,
        deletedAt: deletedAt,
        updatedAt: _now().toUtc(),
      ),
    );
  }

  Duration _backoffFor(int retryCount) {
    final multiplier = 1 << (retryCount - 1);
    final candidateMs = baseBackoff.inMilliseconds * multiplier;
    final boundedMs = candidateMs.clamp(
      baseBackoff.inMilliseconds,
      maxBackoff.inMilliseconds,
    );
    return Duration(milliseconds: boundedMs);
  }

  String _remoteRecordIdFor({
    required String userId,
    required String localRecordId,
  }) {
    final normalized = localRecordId.trim().toLowerCase();
    if (_uuidRegex.hasMatch(normalized)) {
      return normalized;
    }

    final source = '$userId:$localRecordId';
    final bytes = List<int>.filled(16, 0);
    for (var index = 0; index < source.length; index++) {
      final codeUnit = source.codeUnitAt(index);
      final slot = index % 16;
      bytes[slot] = (bytes[slot] + codeUnit + slot) & 0xFF;
    }

    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    return _toUuid(bytes);
  }

  String _toUuid(List<int> bytes) {
    String h(int value) => value.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(h).toList(growable: false);
    return '${b[0]}${b[1]}${b[2]}${b[3]}-${b[4]}${b[5]}-${b[6]}${b[7]}-${b[8]}${b[9]}-${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }

  static final _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
}

class _DispatchResult {
  const _DispatchResult({
    required this.item,
    required this.removeFromQueue,
    this.appliedVersion,
    this.deletedAt,
  });

  final PushQueueItem item;
  final bool removeFromQueue;
  final int? appliedVersion;
  final DateTime? deletedAt;
}
