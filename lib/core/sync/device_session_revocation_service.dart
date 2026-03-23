import 'device_registration_repository.dart';
import 'device_registration_service.dart';
import 'sync_runtime_hardening.dart';

class DeviceSessionView {
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

  final String deviceId;
  final String? deviceName;
  final String? platform;
  final String? appVersion;
  final DateTime? lastSeenAt;
  final bool isCurrentDevice;
  final bool isRevoked;
  final DeviceSessionStatus status;
  final DateTime? revokedAt;
}

class DeviceSessionRevocationService {
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
  final int maxRetryAttempts;
  final Duration baseRetryDelay;
  final SyncDiagnosticsHook? diagnosticsHook;
  final Future<void> Function(Duration delay) _delay;
  final DateTime Function() _now;

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

  Future<void> revokeDevice({required String deviceId}) async {
    await _runWithRetryVoid(
      operationName: 'revoke_device',
      action: () => _repository.revokeDevice(deviceId: deviceId),
    );
  }

  Future<void> revokeAllOtherDevices() async {
    final currentDeviceId = await _identityService.getOrCreateDeviceId();
    await _runWithRetryVoid(
      operationName: 'revoke_other_devices',
      action: () =>
          _repository.revokeAllOtherDevices(currentDeviceId: currentDeviceId),
    );
  }

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
