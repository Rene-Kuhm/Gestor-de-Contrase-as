import 'device_registration_repository.dart';
import 'device_registration_service.dart';

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
  }) : _repository = repository,
       _identityService = identityService;

  final DeviceRegistrationRepository _repository;
  final DeviceIdentityService _identityService;

  Future<List<DeviceSessionView>> listDevices() async {
    final currentDeviceId = await _identityService.getOrCreateDeviceId();
    final devices = await _repository.listDevices();

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

  Future<void> revokeDevice({required String deviceId}) {
    return _repository.revokeDevice(deviceId: deviceId);
  }

  Future<void> revokeAllOtherDevices() async {
    final currentDeviceId = await _identityService.getOrCreateDeviceId();
    await _repository.revokeAllOtherDevices(currentDeviceId: currentDeviceId);
  }

  Future<String> readCurrentDeviceId() {
    return _identityService.getOrCreateDeviceId();
  }
}
