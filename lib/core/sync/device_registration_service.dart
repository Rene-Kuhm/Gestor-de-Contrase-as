import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../security/secure_storage_service.dart';
import 'incremental_pull_sync_service.dart';
import 'incremental_push_sync_service.dart';
import 'local_vault_mutation.dart';
import 'device_registration_repository.dart';

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

  Future<void> registerCurrentDevice() async {
    final metadata = await _readMetadata();
    await _repository.registerDevice(
      deviceId: metadata.deviceId,
      deviceName: metadata.deviceName,
      platform: metadata.platform,
      appVersion: metadata.appVersion,
      lastSeenAt: metadata.lastSeenAt,
    );
  }

  Future<void> sendHeartbeat() async {
    final metadata = await _readMetadata();
    await _repository.sendHeartbeat(
      deviceId: metadata.deviceId,
      deviceName: metadata.deviceName,
      platform: metadata.platform,
      appVersion: metadata.appVersion,
      lastSeenAt: metadata.lastSeenAt,
    );
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
    IncrementalPullSyncService? pullSyncService,
    IncrementalPushSyncService? pushSyncService,
    RelayLocalVaultMutationSink? mutationSink,
    this.heartbeatInterval = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _service = service,
       _pullSyncService = pullSyncService,
       _pushSyncService = pushSyncService,
       _mutationSink = mutationSink,
       _now = now ?? DateTime.now;

  final DeviceRegistrationService _service;
  final IncrementalPullSyncService? _pullSyncService;
  final IncrementalPushSyncService? _pushSyncService;
  final RelayLocalVaultMutationSink? _mutationSink;
  final Duration heartbeatInterval;
  final DateTime Function() _now;

  DateTime? _lastHeartbeatAt;
  bool _registered = false;

  Future<void> onSessionStarted() async {
    await _service.registerCurrentDevice();
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
    if (!_registered) {
      await onSessionStarted();
      return;
    }

    final lastHeartbeatAt = _lastHeartbeatAt;
    final shouldSendHeartbeat =
        lastHeartbeatAt == null ||
        _now().difference(lastHeartbeatAt) >= heartbeatInterval;
    if (shouldSendHeartbeat) {
      await _service.sendHeartbeat();
      _lastHeartbeatAt = _now();
    }

    await _pushSyncService?.onAppResumed();
    await _pullSyncService?.onAppResumed();
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
