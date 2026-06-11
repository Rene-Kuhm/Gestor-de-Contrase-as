# Proposal: vaulta-sync-migration (T4 de ADR-004)

> Migración de los dos consumidores de los servicios viejos
> (`IncrementalPullSyncService` + `IncrementalPushSyncService`) al
> nuevo `BidirectionalSyncService`. Es el T4 del roadmap de
> `docs/architecture/ADR-004-roadmap-sync.md`.

## Intent

Cerrar el estado transitorio del sync layer. Hoy coexisten tres
servicios (`BidirectionalSyncService` + los dos deprecados) pero solo
los viejos son los que `device_sync_bootstrap.dart` y
`DeviceSyncLifecycle` instancian. Esto contradice la decision
del ADR-004 ("BidirectionalSyncService es la base") y deja el
codebase en un limbo donde `flutter analyze` muestra `@Deprecated`
warnings sin que nadie los arregle porque los consumers siguen
usando lo viejo.

Resultado esperado:
- `IncrementalPullSyncService` y `IncrementalPushSyncService` siguen
  existiendo (T5 los borra en un follow-up aparte).
- Los dos consumers usan `BidirectionalSyncService` exclusivamente.
- `DeviceSyncLifecycle` toma un solo `syncService` (no dos separados).
- Tests verdes, analyze limpio.

## Scope

### In Scope
- Refactor de `device_sync_bootstrap.dart` para instanciar
  `BidirectionalSyncService` en lugar de los dos servicios viejos.
- Refactor de `DeviceSyncLifecycle` (en
  `device_registration_service.dart`) para tomar un solo
  `syncService` opcional. Eliminacion de los params `pullSyncService`
  y `pushSyncService`.
- Wiring del `conflictResolver.triggerPushSync` al
  `syncService.runNow` (que dispara un drain de push, igual que
  hacia `pushSyncService.runNow` antes).
- Tests de `DeviceSyncLifecycle` actualizados para usar la nueva
  API; agregar un test que verifique que `syncService.onSessionStarted`
  se llama en el flujo de session-start.
- 1-2 commits logicos: uno para `device_sync_bootstrap.dart`, otro
  para `DeviceSyncLifecycle` + tests.

### Out of Scope
- Borrar `IncrementalPullSyncService.dart` y
  `incremental_push_sync_service.dart` (eso es T5 de ADR-004,
  un change aparte). Por ahora siguen con `@Deprecated` y nadie
  los importa — eventualmente T5 los borra cuando el IDE les
  marque 0 references.
- Cambios en el formato del vault, en el cifrado, o en el sync
  contract.
- Extender la regla `public_member_api_docs` a `lib/app/` y
  `lib/features/` (eso es el change `vaulta-public-api-docs-extended`,
  se hace en otra sesion).

## Capabilities

### Modified Capabilities
- `bidirectional-sync`: ahora se ejerce desde los dos consumers;
  hasta ahora solo se testeaba en aislamiento.

## Approach

### Fase 1: device_sync_bootstrap.dart

Cambios:
- Eliminar las dos `IncrementalPullSyncService` /
  `IncrementalPushSyncService` instantiations.
- Crear una sola `BidirectionalSyncService` con los mismos
  parametros que tenia `IncrementalPullSyncService` (incluido el
  `applyLocalSnapshots`).
- `SyncConflictResolver(triggerPushSync: ...)` ahora recibe
  `syncService.runNow`.
- `mutationSink?.attach(...)` ahora recibe `syncService`.
- `DeviceSyncLifecycle(...)` recibe `syncService: syncService` (un
  solo param) en lugar de los dos separados.

### Fase 2: DeviceSyncLifecycle (device_registration_service.dart)

Cambios:
- Reemplazar `IncrementalPullSyncService? pullSyncService` +
  `IncrementalPushSyncService? pushSyncService` por un solo
  `BidirectionalSyncService? syncService`.
- Reemplazar `_pullSyncService?.onSessionStarted()` +
  `_pushSyncService?.onSessionStarted()` por
  `_syncService?.onSessionStarted()` (el nuevo servicio corre
  pull y push internamente).
- Reemplazar `_pullSyncService?.onAppResumed()` +
  `_pushSyncService?.onAppResumed()` por
  `_syncService?.onAppResumed()`.

### Fase 3: Tests

- Los tests existentes en `device_registration_service_test.dart`
  NO pasan `pullSyncService`/`pushSyncService` al lifecycle, asi
  que siguen pasando sin cambios (siguen testeando solo la logica
  de registration/heartbeat/revocation).
- `security_gate_test.dart` tampoco pasa sync services al
  lifecycle, sigue pasando sin cambios.
- Agregar un test nuevo en `device_registration_service_test.dart`
  que verifique que `syncService.onSessionStarted` y
  `syncService.onAppResumed` se llaman cuando el lifecycle los
  invoca.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/core/sync/device_sync_bootstrap.dart` | Modified | Single service instantiation |
| `lib/core/sync/device_registration_service.dart` | Modified | `DeviceSyncLifecycle` API: pullSyncService + pushSyncService -> syncService |
| `test/core/sync/device_registration_service_test.dart` | Modified | New test for syncService wiring |
| `lib/core/sync/incremental_pull_sync_service.dart` | Unchanged | Sigue con `@Deprecated` hasta T5 |
| `lib/core/sync/incremental_push_sync_service.dart` | Unchanged | Sigue con `@Deprecated` hasta T5 |
| `test/core/sync/incremental_pull_sync_service_test.dart` | Unchanged | Sigue verde (test del servicio viejo) |
| `test/core/sync/incremental_push_sync_service_test.dart` | Unchanged | Sigue verde (test del servicio viejo) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Breaking change en `DeviceSyncLifecycle` API afecta a otros call sites | Low | El unico call site del lifecycle ademas del bootstrap es el test de `security_gate_test.dart`, que no pasa los params removidos. Verificado con grep. |
| Conflicto de timing en el wiring: el lifecycle llama `_syncService.onSessionStarted()` pero el sync service necesita `mutationSink` ya atado para recibir mutaciones | Low | El bootstrap hace `mutationSink?.attach(syncService)` ANTES de crear el lifecycle. Orden ya correcto en el codigo viejo, lo preservamos. |
| Tests de los servicios viejos fallan porque los archivos cambiados en este change los importan | Low | No tocamos los archivos de los servicios viejos. Solo los consumers. Los tests viejos siguen importandolos y siguen pasando. |
| `BidirectionalSyncService.runNow` se comporta diferente a `IncrementalPushSyncService.runNow` | Low | `BidirectionalSyncService.runNow` es semánticamente identico: `_triggerPush()` que drena la queue con el mutex. Verificado en `bidirectional_sync_service_test.dart`. |

## Rollback Plan

Revert de los commits de este change. Los servicios viejos siguen
existiendo (no se borran), asi que el revert devuelve al estado
anterior sin data corruption.

## Success Criteria

- [ ] `flutter analyze` retorna `No issues found!` (los `@Deprecated`
      warnings desaparecen porque no hay mas consumers).
- [ ] `flutter test` pasa los 92 tests existentes + el test nuevo
      del wiring de `syncService` (>= 93 verde).
- [ ] Coverage gate sigue en OK (52.4% en `lib/core/security/`).
- [ ] `git grep "pullSyncService\|pushSyncService"` en
      `lib/` retorna 0 resultados.
- [ ] Los archivos `incremental_pull_sync_service.dart` y
      `incremental_push_sync_service.dart` siguen existiendo con
      `@Deprecated` (no se borran aca, eso es T5).