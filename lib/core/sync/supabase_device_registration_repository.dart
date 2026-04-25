import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_registration_repository.dart';

class SupabaseDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  SupabaseDeviceRegistrationRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<DeviceAccessStatus> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  }) async {
    final response = await _client.rpc(
      'rpc_vault_register_device',
      params: {
        'p_device_id': deviceId,
        'p_device_name': deviceName,
        'p_platform': platform,
        'p_app_version': appVersion,
        'p_last_seen_at': lastSeenAt.toIso8601String(),
      },
    );

    return _readAccessStatus(response);
  }

  @override
  Future<DeviceAccessStatus> sendHeartbeat({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  }) async {
    final response = await _client.rpc(
      'rpc_vault_device_heartbeat',
      params: {
        'p_device_id': deviceId,
        'p_device_name': deviceName,
        'p_platform': platform,
        'p_app_version': appVersion,
        'p_last_seen_at': lastSeenAt.toIso8601String(),
      },
    );

    return _readAccessStatus(response);
  }

  @override
  Future<DeviceAccessStatus> readDeviceAccessStatus({
    required String deviceId,
  }) async {
    final response = await _client.rpc(
      'rpc_vault_device_access_status',
      params: {'p_device_id': deviceId},
    );
    return _readAccessStatus(response);
  }

  @override
  Future<List<VaultDeviceSession>> listDevices() async {
    final response = await _client.rpc('rpc_vault_list_devices');
    if (response is! List) {
      return const [];
    }

    final rows = response.cast<Map<String, dynamic>>();
    return rows
        .map(VaultDeviceSessionParser.fromRpcRow)
        .toList(growable: false);
  }

  @override
  Future<void> revokeDevice({required String deviceId}) async {
    await _client.rpc(
      'rpc_vault_revoke_device',
      params: {'p_device_id': deviceId},
    );
  }

  @override
  Future<void> revokeAllOtherDevices({required String currentDeviceId}) async {
    await _client.rpc(
      'rpc_vault_revoke_all_other_devices',
      params: {'p_current_device_id': currentDeviceId},
    );
  }

  DeviceAccessStatus _readAccessStatus(dynamic response) {
    final row = _readSingleRpcRow(response);
    return DeviceAccessStatus(
      accessAllowed: row['access_allowed'] as bool? ?? false,
      reason: _parseReason(row['result_code'] as String?),
      message: row['message'] as String?,
      revokedAt: _readNullableDateTime(row['revoked_at']),
      revokeAllAfter: _readNullableDateTime(row['revoke_all_after']),
    );
  }

  Map<String, dynamic> _readSingleRpcRow(dynamic response) {
    if (response is! List || response.isEmpty) {
      throw const FormatException('RPC response is empty.');
    }

    final first = response.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('RPC response row has invalid format.');
    }

    return first;
  }

  DeviceAccessRevocationReason _parseReason(String? code) {
    return switch (code) {
      'registered' ||
      'heartbeat_ok' ||
      'allowed' => DeviceAccessRevocationReason.unknown,
      'revoked_device' => DeviceAccessRevocationReason.deviceRevoked,
      'revoked_all' => DeviceAccessRevocationReason.allSessionsRevoked,
      'unauthenticated' => DeviceAccessRevocationReason.unauthenticated,
      'invalid_device' => DeviceAccessRevocationReason.invalidDevice,
      'unknown_device' => DeviceAccessRevocationReason.unknownDevice,
      _ => DeviceAccessRevocationReason.unknown,
    };
  }

  DateTime? _readNullableDateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.parse(value).toUtc();
  }
}

final class VaultDeviceSessionParser {
  static VaultDeviceSession fromRpcRow(Map<String, dynamic> row) {
    return VaultDeviceSession(
      deviceId: row['device_id'] as String? ?? '',
      status: _parseStatus(row['status_code'] as String?),
      accessAllowed: row['access_allowed'] as bool? ?? true,
      deviceName: row['device_name'] as String?,
      platform: row['platform'] as String?,
      appVersion: row['app_version'] as String?,
      createdAt: _readNullableDateTime(row['created_at']),
      lastSeenAt: _readNullableDateTime(row['last_seen_at']),
      revokedAt: _readNullableDateTime(row['revoked_at']),
      revokeAllAfter: _readNullableDateTime(row['revoke_all_after']),
    );
  }

  static DeviceSessionStatus _parseStatus(String? code) {
    return switch (code) {
      'active' => DeviceSessionStatus.active,
      'revoked_device' => DeviceSessionStatus.revokedDevice,
      'revoked_all' => DeviceSessionStatus.revokedAll,
      _ => DeviceSessionStatus.unknown,
    };
  }

  static DateTime? _readNullableDateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.parse(value).toUtc();
  }
}
