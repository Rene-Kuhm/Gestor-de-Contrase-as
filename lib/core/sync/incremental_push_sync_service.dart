import 'package:uuid/uuid.dart';

import 'local_remote_vault_store.dart';
import 'local_vault_mutation.dart';
import 'remote_vault_blob_change.dart';
import 'remote_vault_sync_repository.dart';

class IncrementalPushSyncService implements LocalVaultMutationSink {
  IncrementalPushSyncService({
    required RemoteVaultSyncRepository repository,
    required LocalRemoteVaultStore localStore,
    required Future<String> Function() readDeviceId,
    Uuid? uuid,
    this.maxItemsPerRun = 20,
    this.baseBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(minutes: 2),
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
      final result = await _dispatch(deviceId: deviceId, item: prepared);
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
    if (item.status == PushQueueStatus.failed) {
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
    required String deviceId,
    required PushQueueItem item,
  }) async {
    try {
      final response = await _sendToRemote(deviceId: deviceId, item: item);
      return _interpretResponse(item: item, response: response);
    } catch (_) {
      final retryCount = item.retryCount + 1;
      return _DispatchResult(
        item: item.copyWith(
          status: PushQueueStatus.retry,
          retryCount: retryCount,
          nextAttemptAt: _now().toUtc().add(_backoffFor(retryCount)),
          lastResultCode: 'transport_error',
          lastMessage: 'Push failed before receiving RPC result.',
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
        aad: item.aad,
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

  _DispatchResult _interpretResponse({
    required PushQueueItem item,
    required RemoteVaultPushResult response,
  }) {
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

    if (response.code == RemoteVaultPushResultCode.casConflict ||
        response.code == RemoteVaultPushResultCode.idempotencyMismatch) {
      return _DispatchResult(
        item: item.copyWith(
          status: PushQueueStatus.failed,
          lastResultCode: response.code.name,
          lastMessage: response.message,
          nextAttemptAt: null,
          updatedAt: updatedAt,
        ),
        removeFromQueue: false,
      );
    }

    final retryCount = item.retryCount + 1;
    return _DispatchResult(
      item: item.copyWith(
        status: PushQueueStatus.retry,
        retryCount: retryCount,
        nextAttemptAt: _now().toUtc().add(_backoffFor(retryCount)),
        lastResultCode: response.code.name,
        lastMessage: response.message,
        updatedAt: updatedAt,
      ),
      removeFromQueue: false,
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
        aad: deletedAt == null ? item.aad : null,
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
