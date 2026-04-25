import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../security/secure_storage_service.dart';
import 'incremental_pull_sync_service.dart';
import 'incremental_push_sync_service.dart';
import 'local_vault_mutation.dart';
import 'device_registration_repository.dart';
import 'device_session_revocation_service.dart';
import 'sync_conflict_resolver.dart';
import 'sync_runtime_hardening.dart';

abstract interface class AppVersionProvider {
  Future<String> readAppVersion();
}

class PackageInfoAppVersionProvider implements AppVersionProvider {
  @override
  Future<String> readAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (packageInfo.version.isEmpty) {
      return 'unknown';
    }

    if (packageInfo.buildNumber.isEmpty) {
      return packageInfo.version;
    }

    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }
}

abstract interface class DeviceIdentityService {
  Future<String> getOrCreateDeviceId();

  Future<String> readDeviceName();

  String readPlatform();
}

class LocalDeviceIdentityService implements DeviceIdentityService {
  LocalDeviceIdentityService({
    required SecureStorageService storage,
    Uuid? uuid,
  }) : _storage = storage,
       _uuid = uuid ?? const Uuid();

  static const deviceIdKey = 'vault_sync_device_id';

  final SecureStorageService _storage;
  final Uuid _uuid;

  @override
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(deviceIdKey);
    final normalized = existing?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }

    final generated = _uuid.v4();
    await _storage.save(deviceIdKey, generated);
    return generated;
  }

  @override
  Future<String> readDeviceName() async {
    final deviceId = await getOrCreateDeviceId();
    final suffixLength = deviceId.length >= 6 ? 6 : deviceId.length;
    final suffix = deviceId.substring(deviceId.length - suffixLength);
    return 'Vaulta-${readPlatform()}-$suffix';
  }

  @override
  String readPlatform() {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}

class DeviceRegistrationService {
  DeviceRegistrationService({
    required DeviceRegistrationRepository repository,
    required DeviceIdentityService identityService,
    required AppVersionProvider appVersionProvider,
    DateTime Function()? now,
  }) : _repository = repository,
       _identityService = identityService,
       _appVersionProvider = appVersionProvider,
       _now = now ?? DateTime.now;

  final DeviceRegistrationRepository _repository;
  final DeviceIdentityService _identityService;
  final AppVersionProvider _appVersionProvider;
  final DateTime Function() _now;

  Future<DeviceAccessStatus> registerCurrentDevice() async {
    final metadata = await _readMetadata();
    return _repository.registerDevice(
      deviceId: metadata.deviceId,
      deviceName: metadata.deviceName,
      platform: metadata.platform,
      appVersion: metadata.appVersion,
      lastSeenAt: metadata.lastSeenAt,
    );
  }

  Future<DeviceAccessStatus> sendHeartbeat() async {
    final metadata = await _readMetadata();
    return _repository.sendHeartbeat(
      deviceId: metadata.deviceId,
      deviceName: metadata.deviceName,
      platform: metadata.platform,
      appVersion: metadata.appVersion,
      lastSeenAt: metadata.lastSeenAt,
    );
  }

  Future<DeviceAccessStatus> readCurrentDeviceAccessStatus() async {
    final deviceId = await _identityService.getOrCreateDeviceId();
    return _repository.readDeviceAccessStatus(deviceId: deviceId);
  }

  Future<_DeviceRegistrationMetadata> _readMetadata() async {
    final deviceId = await _identityService.getOrCreateDeviceId();
    final deviceName = await _identityService.readDeviceName();
    final appVersion = await _appVersionProvider.readAppVersion();

    return _DeviceRegistrationMetadata(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: _identityService.readPlatform(),
      appVersion: appVersion,
      lastSeenAt: _now().toUtc(),
    );
  }
}

class DeviceSyncLifecycle {
  DeviceSyncLifecycle({
    required DeviceRegistrationService service,
    required this.revocationService,
    IncrementalPullSyncService? pullSyncService,
    IncrementalPushSyncService? pushSyncService,
    this.conflictResolver,
    RelayLocalVaultMutationSink? mutationSink,
    this.onCurrentDeviceRevoked,
    this.maxRetryAttempts = 2,
    this.baseRetryDelay = const Duration(seconds: 1),
    this.heartbeatInterval = const Duration(minutes: 5),
    this.diagnosticsHook,
    Future<void> Function(Duration delay)? delay,
    DateTime Function()? now,
  }) : _service = service,
       _pullSyncService = pullSyncService,
       _pushSyncService = pushSyncService,
       _mutationSink = mutationSink,
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  final DeviceRegistrationService _service;
  final DeviceSessionRevocationService revocationService;
  final IncrementalPullSyncService? _pullSyncService;
  final IncrementalPushSyncService? _pushSyncService;
  final SyncConflictResolver? conflictResolver;
  final RelayLocalVaultMutationSink? _mutationSink;
  final Future<void> Function(DeviceAccessStatus status)?
  onCurrentDeviceRevoked;
  final int maxRetryAttempts;
  final Duration baseRetryDelay;
  final Duration heartbeatInterval;
  final SyncDiagnosticsHook? diagnosticsHook;
  final Future<void> Function(Duration delay) _delay;
  final DateTime Function() _now;

  DateTime? _lastHeartbeatAt;
  bool _registered = false;

  Future<void> onSessionStarted() async {
    if (!await _ensureCurrentDeviceAccess()) {
      return;
    }

    final registrationStatus = await _runWithRetry(
      operationName: 'register_device',
      action: _service.registerCurrentDevice,
    );
    if (registrationStatus == null) {
      return;
    }

    if (!await _ensureAccessAllowed(registrationStatus)) {
      return;
    }

    _registered = true;
    _lastHeartbeatAt = _now();
    final pushSyncService = _pushSyncService;
    final mutationSink = _mutationSink;
    if (pushSyncService != null && mutationSink != null) {
      mutationSink.attach(pushSyncService);
    }
    await pushSyncService?.onSessionStarted();
    await _pullSyncService?.onSessionStarted();
  }

  Future<void> onAppResumed() async {
    if (!await _ensureCurrentDeviceAccess()) {
      return;
    }

    if (!_registered) {
      await onSessionStarted();
      return;
    }

    final lastHeartbeatAt = _lastHeartbeatAt;
    final shouldSendHeartbeat =
        lastHeartbeatAt == null ||
        _now().difference(lastHeartbeatAt) >= heartbeatInterval;
    if (shouldSendHeartbeat) {
      final heartbeatStatus = await _runWithRetry(
        operationName: 'send_heartbeat',
        action: _service.sendHeartbeat,
      );
      if (heartbeatStatus == null) {
        return;
      }

      if (!await _ensureAccessAllowed(heartbeatStatus)) {
        return;
      }
      _lastHeartbeatAt = _now();
    }

    await _pushSyncService?.onAppResumed();
    await _pullSyncService?.onAppResumed();
  }

  Future<bool> _ensureCurrentDeviceAccess() async {
    final status = await _runWithRetry(
      operationName: 'read_access_status',
      action: _service.readCurrentDeviceAccessStatus,
    );
    if (status == null) {
      return false;
    }

    return _ensureAccessAllowed(status);
  }

  Future<bool> _ensureAccessAllowed(DeviceAccessStatus status) async {
    if (!status.isRevoked) {
      return true;
    }

    _registered = false;
    final code = SyncStatusCodes.revokedSessionOrDevice;
    final message = syncMessageForCode(
      code,
      fallback: status.message ?? status.userFacingReason(),
    );
    emitSyncDiagnostic(
      scope: 'session',
      operation: 'ensure_access',
      code: code,
      message: message,
      retriable: false,
      timestamp: _now(),
      hook: diagnosticsHook,
      metadata: {'reason': status.reason?.name ?? 'unknown'},
    );
    debugPrint(
      '[sync][session][revoked] reason=${status.reason?.name ?? 'unknown'} message=$message',
    );
    if (onCurrentDeviceRevoked case final callback?) {
      await callback(status);
    }
    return false;
  }

  Future<T?> _runWithRetry<T>({
    required String operationName,
    required Future<T> Function() action,
  }) async {
    if (maxRetryAttempts < 1) {
      return null;
    }

    Object? lastError;
    for (var attempt = 1; attempt <= maxRetryAttempts; attempt += 1) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        final disposition = classifySyncError(error);
        final code = syncErrorCode(error);
        final message = syncMessageForCode(
          code,
          fallback:
              'No se pudo ejecutar $operationName para validar sesion remota.',
        );
        final retriable = disposition == SyncErrorDisposition.transient;
        emitSyncDiagnostic(
          scope: 'session',
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
        debugPrint(
          '[sync][session][$operationName] attempt=$attempt/$maxRetryAttempts failed: $error',
        );
        if (attempt >= maxRetryAttempts || !retriable) {
          break;
        }

        final delayMs = baseRetryDelay.inMilliseconds * (1 << (attempt - 1));
        await _delay(Duration(milliseconds: delayMs));
      }
    }

    debugPrint(
      '[sync][session][$operationName] aborted after $maxRetryAttempts attempts: ${lastError ?? 'unknown error'}',
    );
    return null;
  }
}

class _DeviceRegistrationMetadata {
  const _DeviceRegistrationMetadata({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.lastSeenAt,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String appVersion;
  final DateTime lastSeenAt;
}
