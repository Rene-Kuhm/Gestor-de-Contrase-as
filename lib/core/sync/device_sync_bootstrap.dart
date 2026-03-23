import 'package:supabase_flutter/supabase_flutter.dart';

import '../security/secure_storage_service.dart';
import 'device_registration_service.dart';
import 'supabase_device_registration_repository.dart';

Future<DeviceSyncLifecycle?> buildDeviceSyncLifecycle({
  required SecureStorageService storage,
}) async {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    return null;
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  final repository = SupabaseDeviceRegistrationRepository(
    client: Supabase.instance.client,
  );
  final service = DeviceRegistrationService(
    repository: repository,
    identityService: LocalDeviceIdentityService(storage: storage),
    appVersionProvider: PackageInfoAppVersionProvider(),
  );

  return DeviceSyncLifecycle(service: service);
}
