import 'package:supabase_flutter/supabase_flutter.dart';

import '../security/secure_storage_service.dart';
import '../security/local_encrypted_vault_repository.dart';
import 'device_registration_repository.dart';
import 'device_registration_service.dart';
import 'device_session_revocation_service.dart';
import 'incremental_pull_sync_service.dart';
import 'incremental_push_sync_service.dart';
import 'local_remote_vault_store.dart';
import 'local_vault_mutation.dart';
import 'supabase_device_registration_repository.dart';
import 'supabase_remote_vault_sync_repository.dart';
import 'sync_conflict_resolver.dart';

Future<DeviceSyncLifecycle?> buildDeviceSyncLifecycle({
  required SecureStorageService storage,
  LocalEncryptedVaultRepository? vaultRepository,
  RelayLocalVaultMutationSink? mutationSink,
  Future<void> Function(DeviceAccessStatus status)? onCurrentDeviceRevoked,
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
  final localStore = LocalRemoteVaultStore(storage: storage);
  final service = DeviceRegistrationService(
    repository: repository,
    identityService: identityService,
    appVersionProvider: PackageInfoAppVersionProvider(),
  );
  final revocationService = DeviceSessionRevocationService(
    repository: repository,
    identityService: identityService,
  );
  final pullSyncService = IncrementalPullSyncService(
    repository: pullRepository,
    localStore: localStore,
    readDeviceId: identityService.getOrCreateDeviceId,
    applyLocalSnapshots: vaultRepository == null
        ? null
        : (snapshots) =>
              vaultRepository.applyRemoteSnapshots(snapshots: snapshots),
  );
  final pushSyncService = IncrementalPushSyncService(
    repository: pullRepository,
    localStore: localStore,
    readDeviceId: identityService.getOrCreateDeviceId,
  );
  final conflictResolver = SyncConflictResolver(
    repository: pullRepository,
    localStore: localStore,
    triggerPushSync: pushSyncService.runNow,
  );
  mutationSink?.attach(pushSyncService);

  return DeviceSyncLifecycle(
    service: service,
    revocationService: revocationService,
    pullSyncService: pullSyncService,
    pushSyncService: pushSyncService,
    conflictResolver: conflictResolver,
    mutationSink: mutationSink,
    onCurrentDeviceRevoked: onCurrentDeviceRevoked,
  );
}
