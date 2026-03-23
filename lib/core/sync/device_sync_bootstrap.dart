import 'package:supabase_flutter/supabase_flutter.dart';

import '../security/secure_storage_service.dart';
import 'device_registration_service.dart';
import 'incremental_pull_sync_service.dart';
import 'local_remote_vault_store.dart';
import 'supabase_device_registration_repository.dart';
import 'supabase_remote_vault_sync_repository.dart';

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
  final pullRepository = SupabaseRemoteVaultSyncRepository(
    client: Supabase.instance.client,
  );
  final identityService = LocalDeviceIdentityService(storage: storage);
  final service = DeviceRegistrationService(
    repository: repository,
    identityService: identityService,
    appVersionProvider: PackageInfoAppVersionProvider(),
  );
  final pullSyncService = IncrementalPullSyncService(
    repository: pullRepository,
    localStore: LocalRemoteVaultStore(storage: storage),
    readDeviceId: identityService.getOrCreateDeviceId,
  );

  return DeviceSyncLifecycle(service: service, pullSyncService: pullSyncService);
}
