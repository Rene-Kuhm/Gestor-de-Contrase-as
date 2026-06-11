# Tasks: vaulta-sync-migration

## T1 — Refactor de `device_sync_bootstrap.dart`

- **Spec**: REQ-MIG-001
- **File**: `lib/core/sync/device_sync_bootstrap.dart`
- **Approach**: rewrite completo preservando imports. Reemplazar
  las dos instantiations por una sola `BidirectionalSyncService`.
  Cablear `SyncConflictResolver(triggerPushSync: syncService.runNow)`.
  Cablear `mutationSink?.attach(syncService)`. Pasar
  `syncService: syncService` al lifecycle.
- **Verify**: compila sin errores, tests existentes siguen
  pasando (no cambian por el bootstrap porque no se mockean los
  services directamente).

## T2 — Refactor de `DeviceSyncLifecycle`

- **Spec**: REQ-MIG-002
- **File**: `lib/core/sync/device_registration_service.dart`
- **Approach**: rewrite del bloque `class DeviceSyncLifecycle`.
  - Reemplazar params `pullSyncService` + `pushSyncService` por
    `syncService`.
  - Reemplazar `_pullSyncService?.onSessionStarted()` +
    `_pushSyncService?.onSessionStarted()` por
    `_syncService?.onSessionStarted()`.
  - Reemplazar `_pullSyncService?.onAppResumed()` +
    `_pushSyncService?.onAppResumed()` por
    `_syncService?.onAppResumed()`.
  - Mantener el resto del lifecycle (registro, heartbeat,
    retries, revocation) intacto.
- **Verify**: tests existentes en
  `device_registration_service_test.dart` siguen pasando
  (no usaban los params removidos).
- **Cuidado**: la regla del lint `prefer_const_constructors` esta
  en la primera linea (`// ignore_for_file: prefer_const_declarations`).
  No agregar nada que rompa ese contrato.

## T3 — Test del wiring de `syncService`

- **Spec**: REQ-MIG-002
- **File**: `test/core/sync/device_registration_service_test.dart`
- **Approach**: agregar un test nuevo en el group
  `DeviceSyncLifecycle` que verifique que
  `syncService.onSessionStarted()` y `syncService.onAppResumed()`
  se llaman cuando el lifecycle los invoca. Usar un
  `_FakeBidirectionalSyncService` que cuente las llamadas a
  `onSessionStarted` y `onAppResumed`.
- **Verify**: test nuevo pasa junto con los 4 tests existentes del
  group.

## Resumen de commits esperados

1. `refactor(sync): consolidate device_sync_bootstrap onto
   BidirectionalSyncService`
2. `refactor(sync): consolidate DeviceSyncLifecycle onto a single
   syncService param + add wiring test`