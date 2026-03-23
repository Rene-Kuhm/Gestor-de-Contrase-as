import 'package:flutter_test/flutter_test.dart';

import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';
import 'package:gestor_contrasenas/core/sync/device_registration_repository.dart';
import 'package:gestor_contrasenas/core/sync/device_registration_service.dart';
import 'package:gestor_contrasenas/core/sync/device_session_revocation_service.dart';

void main() {
  group('LocalDeviceIdentityService', () {
    test('persists generated device id in secure storage', () async {
      final storage = _InMemorySecureStorageService();
      final identityService = LocalDeviceIdentityService(storage: storage);

      final first = await identityService.getOrCreateDeviceId();
      final second = await identityService.getOrCreateDeviceId();

      expect(first, isNotEmpty);
      expect(second, first);
      expect(await storage.read(LocalDeviceIdentityService.deviceIdKey), first);
    });
  });

  group('DeviceSyncLifecycle', () {
    test('registers once and heartbeats only after interval', () async {
      final repository = _FakeDeviceRegistrationRepository();
      final clock = _FakeClock(DateTime.utc(2026, 3, 23, 12));
      final service = DeviceRegistrationService(
        repository: repository,
        identityService: _FakeDeviceIdentityService(),
        appVersionProvider: const _FakeAppVersionProvider('1.0.0+1'),
        now: clock.now,
      );
      final lifecycle = DeviceSyncLifecycle(
        service: service,
        revocationService: DeviceSessionRevocationService(
          repository: repository,
          identityService: _FakeDeviceIdentityService(),
        ),
        heartbeatInterval: const Duration(minutes: 5),
        now: clock.now,
      );

      await lifecycle.onSessionStarted();
      expect(repository.registerCalls, 1);
      expect(repository.heartbeatCalls, 0);
      expect(repository.readStatusCalls, 1);

      clock.advance(const Duration(minutes: 4));
      await lifecycle.onAppResumed();
      expect(repository.heartbeatCalls, 0);

      clock.advance(const Duration(minutes: 1));
      await lifecycle.onAppResumed();
      expect(repository.heartbeatCalls, 1);
      expect(repository.readStatusCalls, 3);
    });

    test('retries transient access check and continues session start', () async {
      final repository = _FakeDeviceRegistrationRepository(
        failReadStatusTimes: 1,
      );
      final service = DeviceRegistrationService(
        repository: repository,
        identityService: _FakeDeviceIdentityService(),
        appVersionProvider: const _FakeAppVersionProvider('1.0.0+1'),
      );
      final lifecycle = DeviceSyncLifecycle(
        service: service,
        revocationService: DeviceSessionRevocationService(
          repository: repository,
          identityService: _FakeDeviceIdentityService(),
        ),
        delay: (_) async {},
      );

      await lifecycle.onSessionStarted();

      expect(repository.readStatusCalls, 2);
      expect(repository.registerCalls, 1);
    });

    test('does not crash when access check keeps failing offline', () async {
      final repository = _FakeDeviceRegistrationRepository(
        failReadStatusTimes: 4,
      );
      final service = DeviceRegistrationService(
        repository: repository,
        identityService: _FakeDeviceIdentityService(),
        appVersionProvider: const _FakeAppVersionProvider('1.0.0+1'),
      );
      final lifecycle = DeviceSyncLifecycle(
        service: service,
        revocationService: DeviceSessionRevocationService(
          repository: repository,
          identityService: _FakeDeviceIdentityService(),
        ),
        delay: (_) async {},
      );

      await lifecycle.onSessionStarted();

      expect(repository.registerCalls, 0);
      expect(repository.readStatusCalls, 2);
    });

    test('locks session when heartbeat reports revocation', () async {
      final repository = _FakeDeviceRegistrationRepository(
        heartbeatStatuses: const [
          DeviceAccessStatus(
            accessAllowed: false,
            reason: DeviceAccessRevocationReason.deviceRevoked,
            message: 'revoked_device',
          ),
        ],
      );
      final clock = _FakeClock(DateTime.utc(2026, 3, 23, 12));
      final service = DeviceRegistrationService(
        repository: repository,
        identityService: _FakeDeviceIdentityService(),
        appVersionProvider: const _FakeAppVersionProvider('1.0.0+1'),
        now: clock.now,
      );

      DeviceAccessStatus? revokedStatus;
      final lifecycle = DeviceSyncLifecycle(
        service: service,
        revocationService: DeviceSessionRevocationService(
          repository: repository,
          identityService: _FakeDeviceIdentityService(),
        ),
        heartbeatInterval: const Duration(minutes: 1),
        now: clock.now,
        onCurrentDeviceRevoked: (status) async {
          revokedStatus = status;
        },
      );

      await lifecycle.onSessionStarted();
      clock.advance(const Duration(minutes: 1));
      await lifecycle.onAppResumed();

      expect(repository.registerCalls, 1);
      expect(repository.heartbeatCalls, 1);
      expect(revokedStatus, isNotNull);
      expect(revokedStatus!.isRevoked, isTrue);
    });
  });
}

class _InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> save(String key, String value) async {
    _values[key] = value;
  }
}

class _FakeDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  _FakeDeviceRegistrationRepository({
    this.failReadStatusTimes = 0,
    List<DeviceAccessStatus>? heartbeatStatuses,
  }) : _heartbeatStatuses = heartbeatStatuses?.toList(growable: true);

  int registerCalls = 0;
  int heartbeatCalls = 0;
  int readStatusCalls = 0;
  int failReadStatusTimes;
  final List<DeviceAccessStatus>? _heartbeatStatuses;

  @override
  Future<DeviceAccessStatus> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  }) async {
    registerCalls += 1;
    return const DeviceAccessStatus(
      accessAllowed: true,
      reason: null,
    );
  }

  @override
  Future<DeviceAccessStatus> sendHeartbeat({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  }) async {
    heartbeatCalls += 1;
    if (_heartbeatStatuses case final statuses? when statuses.isNotEmpty) {
      return statuses.removeAt(0);
    }

    return const DeviceAccessStatus(
      accessAllowed: true,
      reason: null,
    );
  }

  @override
  Future<DeviceAccessStatus> readDeviceAccessStatus({
    required String deviceId,
  }) async {
    readStatusCalls += 1;
    if (failReadStatusTimes > 0) {
      failReadStatusTimes -= 1;
      throw Exception('offline');
    }

    return const DeviceAccessStatus(
      accessAllowed: true,
      reason: null,
    );
  }

  @override
  Future<List<VaultDeviceSession>> listDevices() async {
    return const [];
  }

  @override
  Future<void> revokeDevice({required String deviceId}) async {}

  @override
  Future<void> revokeAllOtherDevices({required String currentDeviceId}) async {}
}

class _FakeDeviceIdentityService implements DeviceIdentityService {
  @override
  Future<String> getOrCreateDeviceId() async => 'device-test-001';

  @override
  String readPlatform() => 'android';

  @override
  Future<String> readDeviceName() async => 'Pixel 8';
}

class _FakeClock {
  _FakeClock(this._current);

  DateTime _current;

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}

class _FakeAppVersionProvider implements AppVersionProvider {
  const _FakeAppVersionProvider(this._version);

  final String _version;

  @override
  Future<String> readAppVersion() async => _version;
}
