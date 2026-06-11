import 'device_registration_repository.dart';
import 'device_registration_service.dart';
import 'sync_runtime_hardening.dart';

/// UI-ready view of a device session, used by the
/// device-management screen. Distinct from [VaultDeviceSession] in
/// that the latter is the raw backend row, while [DeviceSessionView]
/// adds [isCurrentDevice] (computed against the locally-known device
/// id) for the UI to mark "you are here".
class DeviceSessionView {
  /// Builds a [DeviceSessionView] from a [VaultDeviceSession] plus
  /// the current device id. The [isCurrentDevice] flag should be
  /// `true` only for the row that matches the locally-stored id.
  const DeviceSessionView({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.lastSeenAt,
    required this.isCurrentDevice,
    required this.isRevoked,
    required this.status,
    this.revokedAt,
  });

  /// Backend-assigned device id.
  final String deviceId;

  /// User-visible name, or null when the backend has no label.
  final String? deviceName;

  /// Platform string, or null.
  final String? platform;

  /// App version string, or null.
  final String? appVersion;

  /// When the device last sent a heartbeat, or null.
  final DateTime? lastSeenAt;

  /// True when this row matches the locally-known device id.
  final bool isCurrentDevice;

  /// True when [VaultDeviceSession.isRevoked] was true.
  final bool isRevoked;

  /// Backend-reported state.
  final DeviceSessionStatus status;

  /// When the device was revoked, or null if still active.
  final DateTime? revokedAt;
}

/// Internal service that wraps revocation RPCs over a
/// [DeviceRegistrationRepository]. Lives next to its backend adapter
/// inside `lib/core/sync/`. Features must not import this directly;
/// if you need to display device state, go through the public sync
/// APIs wired by [DeviceSyncLifecycle].
class DeviceSessionRevocationService {
  /// Builds a [DeviceSessionRevocationService]. The optional
  /// [maxRetryAttempts], [baseRetryDelay], [diagnosticsHook],
  /// [delay] and [now] are for tests.
  DeviceSessionRevocationService({
    required DeviceRegistrationRepository repository,
    required DeviceIdentityService identityService,
    this.maxRetryAttempts = 2,
    this.baseRetryDelay = const Duration(seconds: 1),
    this.diagnosticsHook,
    Future<void> Function(Duration delay)? delay,
    DateTime Function()? now,
  }) : _repository = repository,
       _identityService = identityService,
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  final DeviceRegistrationRepository _repository;
  final DeviceIdentityService _identityService;

  /// Maximum number of retry attempts for transient failures
  /// (HTTP 408/429/5xx, "timeout", "network", etc.). 0 disables
  /// retries entirely.
  final int maxRetryAttempts;

  /// Initial backoff between retries. Doubles on each attempt.
  final Duration baseRetryDelay;

  /// Optional hook that receives a [SyncDiagnosticEvent] for every
  /// failure. Used by the lifecycle to surface sync issues in the
  /// settings screen.
  final SyncDiagnosticsHook? diagnosticsHook;
  final Future<void> Function(Duration delay) _delay;
  final DateTime Function() _now;

  /// Fetches the full list of devices for the current user, mapped
  /// to UI-ready [DeviceSessionView]s with [DeviceSessionView.isCurrentDevice]
  /// resolved. Returns an empty list on persistent failure (caller
  /// can show an empty state with a retry button).
  Future<List<DeviceSessionView>> listDevices() async {
    final currentDeviceId = await _identityService.getOrCreateDeviceId();
    final devices = await _runWithRetry(
      operationName: 'list_devices',
      action: _repository.listDevices,
    );
    if (devices == null) {
      return const [];
    }

    return devices
        .map(
          (device) => DeviceSessionView(
            deviceId: device.deviceId,
            deviceName: device.deviceName,
            platform: device.platform,
            appVersion: device.appVersion,
            lastSeenAt: device.lastSeenAt,
            isCurrentDevice: device.deviceId == currentDeviceId,
            isRevoked: device.isRevoked,
            status: device.status,
            revokedAt: device.revokedAt,
          ),
        )
        .toList(growable: false);
  }

  /// Revokes [deviceId] on the backend. Retries transient failures
  /// up to [maxRetryAttempts]; definitive failures return without
  /// throwing (caller checks the lifecycle's emitted diagnostic).
  Future<void> revokeDevice({required String deviceId}) async {
    await _runWithRetryVoid(
      operationName: 'revoke_device',
      action: () => _repository.revokeDevice(deviceId: deviceId),
    );
  }

  /// Revokes every device for the current user except the one
  /// matching the locally-known device id. The "log out everywhere
  /// else" flow. Same retry semantics as [revokeDevice].
  Future<void> revokeAllOtherDevices() async {
    final currentDeviceId = await _identityService.getOrCreateDeviceId();
    await _runWithRetryVoid(
      operationName: 'revoke_other_devices',
      action: () =>
          _repository.revokeAllOtherDevices(currentDeviceId: currentDeviceId),
    );
  }

  /// Returns the locally-known device id (generates and persists
  /// one if missing). Convenience accessor for callers that need
  /// the id without going through the identity service directly.
  Future<String> readCurrentDeviceId() {
    return _identityService.getOrCreateDeviceId();
  }

  Future<T?> _runWithRetry<T>({
    required String operationName,
    required Future<T> Function() action,
  }) async {
    if (maxRetryAttempts < 1) {
      return null;
    }

    for (var attempt = 1; attempt <= maxRetryAttempts; attempt += 1) {
      try {
        return await action();
      } catch (error) {
        final disposition = classifySyncError(error);
        final code = syncErrorCode(error);
        final message = syncMessageForCode(
          code,
          fallback:
              'No se pudo completar $operationName en gestion de sesiones.',
        );
        final retriable = disposition == SyncErrorDisposition.transient;
        emitSyncDiagnostic(
          scope: 'revocation',
          operation: operationName,
          code: code,
          message: message,
          retriable: retriable,
          timestamp: _now(),
          hook: diagnosticsHook,
          attempt: attempt,
          maxAttempts: maxRetryAttempts,
          error: error,
        );

        if (attempt >= maxRetryAttempts || !retriable) {
          return null;
        }

        final delayMs = baseRetryDelay.inMilliseconds * (1 << (attempt - 1));
        await _delay(Duration(milliseconds: delayMs));
      }
    }

    return null;
  }

  Future<void> _runWithRetryVoid({
    required String operationName,
    required Future<void> Function() action,
  }) async {
    await _runWithRetry<Object?>(
      operationName: operationName,
      action: () async {
        await action();
        return null;
      },
    );
  }
}
