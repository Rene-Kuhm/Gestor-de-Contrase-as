/// Internal contract for backend-backed device registration and
/// revocation. Implementations live in `lib/core/sync/` and talk to
/// Supabase (or any future backend). Features must not import this
/// directly: depend on the higher-level [DeviceRegistrationService]
/// exposed via [DeviceSyncLifecycle]. This interface is re-exported by
/// `sync_internal.dart` for backend adapters that genuinely need it.
abstract interface class DeviceRegistrationRepository {
  /// Registers the current device against the backend. Idempotent
  /// when called repeatedly for the same [deviceId] (the backend
  /// upserts). Returns the resulting [DeviceAccessStatus] so the
  /// caller can decide whether the device is still allowed in.
  Future<DeviceAccessStatus> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  });

  /// Sends a heartbeat to refresh the device's `lastSeenAt`. The
  /// backend may use this to detect stale devices and revoke them.
  /// Returns the resulting [DeviceAccessStatus].
  Future<DeviceAccessStatus> sendHeartbeat({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  });

  /// Returns the [DeviceAccessStatus] for the given [deviceId]
  /// without performing any mutation. Used by the lifecycle to gate
  /// the unlock flow (if the device was revoked remotely, the
  /// session is invalidated).
  Future<DeviceAccessStatus> readDeviceAccessStatus({required String deviceId});

  /// Returns the full list of devices registered for the current
  /// user. Used by the device-management screen.
  Future<List<VaultDeviceSession>> listDevices();

  /// Revokes [deviceId] on the backend. Idempotent: revoking a
  /// device that is already revoked is a no-op on the server side.
  Future<void> revokeDevice({required String deviceId});

  /// Revokes every device for the current user except
  /// [currentDeviceId]. The typical "log out everywhere else" flow.
  Future<void> revokeAllOtherDevices({required String currentDeviceId});
}

/// Why the backend refused access for a device. The lifecycle
/// surfaces this verbatim in the unlock screen so the user knows
/// whether their device was individually revoked, every session
/// was nuked, or the auth itself is broken.
enum DeviceAccessRevocationReason {
  /// This specific device was revoked by the user from another
  /// device. The vault must lock.
  deviceRevoked,

  /// The user triggered "log out everywhere". Every session must
  /// lock.
  allSessionsRevoked,

  /// The auth token is missing, expired, or invalid.
  unauthenticated,

  /// The device id does not match any registered device.
  invalidDevice,

  /// The device id is well-formed but the backend does not know it.
  unknownDevice,

  /// Catch-all for unclassified failures.
  unknown,
}

/// Current state of a device session in the backend's view.
enum DeviceSessionStatus {
  /// The session is healthy: heartbeat is recent, no revocations.
  active,

  /// The device was individually revoked.
  revokedDevice,

  /// Every session was revoked (a "log out everywhere" ran).
  revokedAll,

  /// Catch-all for unclassified statuses (e.g. backend returned an
  /// unknown status code).
  unknown,
}

/// Snapshot of "is this device allowed to keep its session?" returned
/// by every [DeviceRegistrationRepository] call. The lifecycle uses
/// [isRevoked] to gate the unlock flow and [userFacingReason] to
/// surface a localized message in the UI.
class DeviceAccessStatus {
  /// Builds a [DeviceAccessStatus] from a backend response.
  const DeviceAccessStatus({
    required this.accessAllowed,
    required this.reason,
    this.message,
    this.revokedAt,
    this.revokeAllAfter,
  });

  /// True when the backend says the device is still allowed.
  final bool accessAllowed;

  /// Why the backend refused, or `null` when access is allowed.
  final DeviceAccessRevocationReason? reason;

  /// Free-form backend message (often null on success).
  final String? message;

  /// When this device was revoked (per-device). Null when not
  /// revoked.
  final DateTime? revokedAt;

  /// Marker timestamp for "all sessions revoked" cutoffs. A session
  /// whose [lastSeenAt] is before this marker is considered stale
  /// and must re-auth.
  final DateTime? revokeAllAfter;

  /// True when the device is explicitly revoked (per-device or
  /// "log out everywhere"). The unlock screen reads this to decide
  /// whether to render a hard-stop message.
  bool get isRevoked =>
      !accessAllowed &&
      (reason == DeviceAccessRevocationReason.deviceRevoked ||
          reason == DeviceAccessRevocationReason.allSessionsRevoked);

  /// Localized, user-facing explanation of the current status. Used
  /// by the unlock screen and the device-management screen.
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

/// Read-side projection of a device for the device-management
/// screen. Built by [DeviceSessionRevocationService.listDevices] from
/// a [VaultDeviceSession] returned by the backend.
class VaultDeviceSession {
  /// Builds a [VaultDeviceSession] from a backend row (or a test
  /// fixture). The `*At` timestamps can be null when the backend
  /// does not have them yet (e.g. brand-new device).
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

  /// Backend-assigned device id.
  final String deviceId;

  /// Backend-reported state.
  final DeviceSessionStatus status;

  /// True when the device still has access.
  final bool accessAllowed;

  /// User-visible device name (e.g. "Vaulta-android-7b3a1f").
  final String? deviceName;

  /// Platform string ("android", "ios", "windows", etc.).
  final String? platform;

  /// App version running on the device (e.g. "1.0.21+22").
  final String? appVersion;

  /// When the device first registered. Null if unknown.
  final DateTime? createdAt;

  /// When the device last sent a heartbeat. Null if never.
  final DateTime? lastSeenAt;

  /// When the device was revoked. Null if active.
  final DateTime? revokedAt;

  /// Marker timestamp for "all sessions revoked" cutoffs. A session
  /// whose [lastSeenAt] is before this marker is considered stale.
  final DateTime? revokeAllAfter;

  /// True when this session should be treated as revoked for UI
  /// purposes. Combines [accessAllowed], [status], [revokedAt] and
  /// the [revokeAllAfter] marker against [lastSeenAt]/[createdAt].
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
