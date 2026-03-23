import 'package:flutter_test/flutter_test.dart';

import 'package:gestor_contrasenas/core/sync/device_registration_repository.dart';
import 'package:gestor_contrasenas/core/sync/device_registration_service.dart';
import 'package:gestor_contrasenas/core/sync/device_session_revocation_service.dart';

void main() {
  group('DeviceSessionRevocationService', () {
    test('lists devices and marks current device', () async {
      final repository = _FakeDeviceRegistrationRepository(
        devices: const [
          VaultDeviceSession(
            deviceId: 'current-device',
            deviceName: 'Pixel 8',
            status: DeviceSessionStatus.active,
            accessAllowed: true,
          ),
          VaultDeviceSession(
            deviceId: 'other-device',
            deviceName: 'Laptop',
            status: DeviceSessionStatus.active,
            accessAllowed: true,
            revokedAt: null,
          ),
        ],
      );
      final service = DeviceSessionRevocationService(
        repository: repository,
        identityService: const _FakeDeviceIdentityService('current-device'),
      );

      final sessions = await service.listDevices();

      expect(sessions, hasLength(2));
      expect(sessions.first.isCurrentDevice, isTrue);
      expect(sessions.last.isCurrentDevice, isFalse);
    });

    test('revokeAllOtherDevices uses current identity id', () async {
      final repository = _FakeDeviceRegistrationRepository(devices: const []);
      final service = DeviceSessionRevocationService(
        repository: repository,
        identityService: const _FakeDeviceIdentityService('device-123'),
      );

      await service.revokeAllOtherDevices();

      expect(repository.lastRevokeOthersCurrentDeviceId, 'device-123');
    });
  });
}

class _FakeDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  _FakeDeviceRegistrationRepository({required this.devices});

  final List<VaultDeviceSession> devices;
  String? lastRevokeOthersCurrentDeviceId;

  @override
  Future<List<VaultDeviceSession>> listDevices() async => devices;

  @override
  Future<DeviceAccessStatus> readDeviceAccessStatus({
    required String deviceId,
  }) async {
    return const DeviceAccessStatus(accessAllowed: true, reason: null);
  }

  @override
  Future<DeviceAccessStatus> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  }) async {
    return const DeviceAccessStatus(accessAllowed: true, reason: null);
  }

  @override
  Future<void> revokeAllOtherDevices({required String currentDeviceId}) async {
    lastRevokeOthersCurrentDeviceId = currentDeviceId;
  }

  @override
  Future<void> revokeDevice({required String deviceId}) async {}

  @override
  Future<DeviceAccessStatus> sendHeartbeat({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  }) async {
    return const DeviceAccessStatus(accessAllowed: true, reason: null);
  }
}

class _FakeDeviceIdentityService implements DeviceIdentityService {
  const _FakeDeviceIdentityService(this._deviceId);

  final String _deviceId;

  @override
  Future<String> getOrCreateDeviceId() async => _deviceId;

  @override
  String readPlatform() => 'android';

  @override
  Future<String> readDeviceName() async => 'Device';
}
