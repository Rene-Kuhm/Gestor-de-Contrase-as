import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_registration_repository.dart';

class SupabaseDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  SupabaseDeviceRegistrationRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  }) async {
    await _client.rpc(
      'rpc_vault_register_device',
      params: {
        'p_device_id': deviceId,
        'p_device_name': deviceName,
        'p_platform': platform,
        'p_app_version': appVersion,
        'p_last_seen_at': lastSeenAt.toIso8601String(),
      },
    );
  }

  @override
  Future<void> sendHeartbeat({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String appVersion,
    required DateTime lastSeenAt,
  }) async {
    await _client.rpc(
      'rpc_vault_device_heartbeat',
      params: {
        'p_device_id': deviceId,
        'p_device_name': deviceName,
        'p_platform': platform,
        'p_app_version': appVersion,
        'p_last_seen_at': lastSeenAt.toIso8601String(),
      },
    );
  }
}
