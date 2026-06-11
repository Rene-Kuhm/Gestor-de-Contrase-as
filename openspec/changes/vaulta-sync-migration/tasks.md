# Tasks: vaulta-sync-migration

> Change cerrado. Los 2 commits del plan se aplicaron en
> orden. CI retorna success, 94 tests verdes, coverage gate
> verde.

## Estado: COMPLETO (2026-06-11)

## Commits del change (en orden cronológico)

| # | Commit | Mensaje | Cubre |
|---|--------|---------|-------|
| 1 | `af3a823` | `refactor(sync): consolidate device_sync_bootstrap onto BidirectionalSyncService` | T1 |
| 2 | `ade5bc9` | `refactor(sync): consolidate DeviceSyncLifecycle onto a single syncService param + add wiring tests` | T2, T3 |

## Tasks por spec

### T1 — Refactor de `device_sync_bootstrap.dart`

- **Spec**: REQ-MIG-001
- **File**: `lib/core/sync/device_sync_bootstrap.dart`
- **Approach**:
  - Eliminar las dos instantiations de
    `IncrementalPullSyncService` /
    `IncrementalPushSyncService`.
  - Crear una sola `BidirectionalSyncService` con los
    mismos parámetros que tenía
    `IncrementalPullSyncService` (incluido
    `applyLocalSnapshots`).
  - `SyncConflictResolver(triggerPushSync: ...)` recibe
    `syncService.runNow`.
  - `mutationSink?.attach(...)` recibe `syncService`.
  - `DeviceSyncLifecycle(...)` recibe
    `syncService: syncService` (un solo param).
- **Verify**:
  - Compila sin errores.
  - Tests existentes siguen pasando.
  - `flutter analyze` 0 issues.
- **Estado**: COMPLETO en `af3a823`.

### T2 — Refactor de `DeviceSyncLifecycle`

- **Spec**: REQ-MIG-002
- **File**: `lib/core/sync/device_registration_service.dart`
- **Approach**:
  - Reemplazar params `pullSyncService` + `pushSyncService`
    por `syncService`.
  - Reemplazar `_pullSyncService?.onSessionStarted()` +
    `_pushSyncService?.onSessionStarted()` por
    `_syncService?.onSessionStarted()`.
  - Reemplazar `_pullSyncService?.onAppResumed()` +
    `_pushSyncService?.onAppResumed()` por
    `_syncService?.onAppResumed()`.
  - Mantener el resto del lifecycle (registro, heartbeat,
    retries, revocation) intacto.
- **Cuidado**: la regla del lint `prefer_const_constructors`
  está en la primera línea del archivo
  (`// ignore_for_file: prefer_const_declarations`). No
  agregar nada que rompa ese contrato.
- **Verify**:
  - Tests existentes en
    `device_registration_service_test.dart` siguen pasando.
  - `flutter analyze` 0 issues.
- **Estado**: COMPLETO en `ade5bc9`.

### T3 — Test del wiring de `syncService`

- **Spec**: REQ-MIG-002 (scenario "lifecycle invoca
  syncService.onSessionStarted" + "lifecycle invoca
  syncService.onAppResumed")
- **File**: `test/core/sync/device_registration_service_test.dart`
- **Approach**: agregar un test nuevo en el group
  `DeviceSyncLifecycle` que verifique que
  `syncService.onSessionStarted()` y
  `syncService.onAppResumed()` se llaman cuando el lifecycle
  los invoca. Usar un `_FakeBidirectionalSyncService` que
  cuente las llamadas a `onSessionStarted` y
  `onAppResumed`.
- **Verify**: test nuevo pasa junto con los 4 tests
  existentes del group.
- **Estado**: COMPLETO en `ade5bc9`.

## Verificación final

- `flutter analyze`: 0 issues. Los `@Deprecated` warnings
  desaparecen porque no hay más consumers.
- `flutter test`: 94/94 tests verdes (92 viejos + 2 nuevos
  del wiring de `syncService`).
- Coverage gate: `OK: 52.4% >= 50%` sobre
  `lib/core/security/`.
- `git grep "pullSyncService\|pushSyncService"` en `lib/`:
  0 resultados.
- CI workflow `Flutter CI`: success.
- 2 commits en master con mensajes conventional.

## Lecciones aprendidas

- **El orden de wiring importa**: el bootstrap hace
  `mutationSink?.attach(syncService)` ANTES de crear el
  lifecycle. Sin ese orden, el lifecycle invocaría
  `syncService.onSessionStarted()` antes de que el
  mutation sink esté conectado, y los pushes del primer
  trigger se perderían.
- **API más simple = menos params = menos bugs**: el
  lifecycle pasó de 2 params opcionales
  (`pullSyncService`, `pushSyncService`) a 1
  (`syncService`). Esto elimina el caso de borde donde
  solo uno de los dos era provisto.
- **TDD con fakes es barato**: 98 líneas de test para un
  wiring crítico. El `_FakeBidirectionalSyncService` que
  cuenta llamadas es trivial de escribir y lee claro.
- **El lint `prefer_const_constructors` no molesta en este
  refactor** porque el lifecycle no tiene constantes que
  dependan de la decisión de wiring.

## Trabajo downstream (posterior, en otros changes)

- T5 de ADR-004: borrar los 2 servicios viejos cuando 0
  references → parte de
  `vaulta-public-api-docs-extended` (cerrado en commit
  `7bf96fc` del master). El T5 elimina 4 archivos:
  - `lib/core/sync/incremental_pull_sync_service.dart`
  - `lib/core/sync/incremental_push_sync_service.dart`
  - `test/core/sync/incremental_pull_sync_service_test.dart`
  - `test/core/sync/incremental_push_sync_service_test.dart`
  - Y actualiza los docstring references en
    `bidirectional_sync_service.dart`,
    `device_registration_service.dart`, y
    `local_vault_mutation.dart` para apuntar al servicio
    nuevo.
