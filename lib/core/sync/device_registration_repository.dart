abstract interface class DeviceRegistrationRepository {
  Future<DeviceAccessStatus> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  });

  Future<DeviceAccessStatus> sendHeartbeat({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  });

  Future<DeviceAccessStatus> readDeviceAccessStatus({required String deviceId});

  Future<List<VaultDeviceSession>> listDevices();

  Future<void> revokeDevice({required String deviceId});

  Future<void> revokeAllOtherDevices({required String currentDeviceId});
}

enum DeviceAccessRevocationReason {
  deviceRevoked,
  allSessionsRevoked,
  unauthenticated,
  invalidDevice,
  unknownDevice,
  unknown,
}

enum DeviceSessionStatus { active, revokedDevice, revokedAll, unknown }

class DeviceAccessStatus {
  const DeviceAccessStatus({
    required this.accessAllowed,
    required this.reason,
    this.message,
    this.revokedAt,
    this.revokeAllAfter,
  });

  final bool accessAllowed;
  final DeviceAccessRevocationReason? reason;
  final String? message;
  final DateTime? revokedAt;
  final DateTime? revokeAllAfter;

  bool get isRevoked =>
      !accessAllowed &&
      (reason == DeviceAccessRevocationReason.deviceRevoked ||
          reason == DeviceAccessRevocationReason.allSessionsRevoked);

  String userFacingReason() {
    return switch (reason) {
      DeviceAccessRevocationReason.deviceRevoked =>
        'Esta sesion se revoco desde otro dispositivo. Vaulta se bloqueo por seguridad.',
      DeviceAccessRevocationReason.allSessionsRevoked =>
        'Se revocaron todas las sesiones activas. Vaulta se bloqueo por seguridad.',
      _ =>
        'No pudimos validar esta sesion remota. Vaulta se bloqueo por seguridad.',
    };
  }
}

class VaultDeviceSession {
  const VaultDeviceSession({
    required this.deviceId,
    required this.status,
    required this.accessAllowed,
    this.deviceName,
    this.platform,
    this.appVersion,
    this.createdAt,
    this.lastSeenAt,
    this.revokedAt,
    this.revokeAllAfter,
  });

  final String deviceId;
  final DeviceSessionStatus status;
  final bool accessAllowed;
  final String? deviceName;
  final String? platform;
  final String? appVersion;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final DateTime? revokedAt;
  final DateTime? revokeAllAfter;

  bool get isRevoked {
    if (!accessAllowed) {
      return true;
    }

    if (status == DeviceSessionStatus.revokedDevice ||
        status == DeviceSessionStatus.revokedAll) {
      return true;
    }

    if (revokedAt != null) {
      return true;
    }

    final marker = revokeAllAfter;
    final reference = lastSeenAt ?? createdAt;
    if (marker != null && reference != null && reference.isBefore(marker)) {
      return true;
    }

    return false;
  }
}
