# Tasks: vaulta-sync-surface-reduction

> Change cerrado. Los 2 commits del plan se aplicaron en
> orden. CI retorna success, 92 tests verdes, coverage gate
> verde.

## Estado: COMPLETO (2026-06-11)

## Commits del change (en orden cronológico)

| # | Commit | Mensaje | Cubre |
|---|--------|---------|-------|
| 1 | `6e65f0d` | `feat(sync): add BidirectionalSyncService consolidating pull+push` | T1 (servicio + tests + scaffolding) |
| 2 | `10a6a51` | `refactor(sync): deprecate old services and add internal barrel` | T2 (internal docs + barrel), T3 (deprecation) |

## Tasks por spec

### T1 — Crear `BidirectionalSyncService` + tests TDD

- **Specs**: REQ-BS-001 a REQ-BS-005
- **Files**:
  - `lib/core/sync/bidirectional_sync_service.dart` (new,
    767 líneas)
  - `test/core/sync/bidirectional_sync_service_test.dart`
    (new, 393 líneas)
- **Approach**: TDD. Escribir tests primero (Red), implementar
  (Green), refactor.
- **API**:
  - `implements LocalVaultMutationSink` (recibe mutaciones
    locales).
  - Lifecycle: `onSessionStarted()`, `onAppResumed()`,
    `runNow()`, `pullNow({bool force = false})`.
  - Estado interno: cursor de pull persistido, `lastPullAt`
    para throttle; queue de push persistida con flag
    `_running` + `_rerunRequested`.
- **Tests cubren**:
  - REQ-BS-001: enqueue de upsert.
  - REQ-BS-002: pull throttled + pull resumes from saved
    cursor.
  - REQ-BS-003: push applied + push cas conflict (registra
    `SyncConflictRecord`).
  - REQ-BS-004: pull retry recovers.
  - REQ-BS-005: diagnósticos se emiten para pull y push.
- **Verify**:
  - `flutter test test/core/sync/bidirectional_sync_service_test.dart`
    pasa.
  - Los tests viejos (`incremental_pull_sync_service_test.dart`,
    `incremental_push_sync_service_test.dart`) siguen pasando
    porque sus servicios no cambian.
- **Estado**: COMPLETO en `6e65f0d`.

### T2 — Marcado interno + `sync_internal.dart`

- **Specs**: REQ-IE-001, REQ-IE-002
- **Files**:
  - `lib/core/sync/device_registration_repository.dart`
    (modified)
  - `lib/core/sync/device_session_revocation_service.dart`
    (modified)
  - `lib/core/sync/sync_internal.dart` (new, 12 líneas)
- **Approach**:
  - Docstrings explícitos en cada interfaz declarando que
    es para uso interno de `lib/core/sync/`.
  - Crear el barrel `sync_internal.dart` que re-exporta
    ambas declaraciones.
- **Desviación documentada**: la propuesta original de usar
  la anotación `@internal` de `package:meta` **no se
  ejecuta**. El lint `invalid_internal_annotation` la
  rechaza: `@internal` solo aplica a elementos privados
  del package (símbolos con `_` o dentro de `lib/src/`).
  Como ambas clases son públicas por diseño de la API, la
  convención queda en (a) docstrings que explican el
  contrato, (b) el barrel `sync_internal.dart` como punto
  único de re-export. La enforcement real (CI grep + lint
  custom) queda para un follow-up dedicado si la convención
  se rompe en la práctica.
- **Verify**:
  - `grep -r 'Features must not import' lib/core/sync/`
    matchea en ambos archivos.
  - `flutter analyze` 0 issues.
  - `lib/core/sync/sync_internal.dart` existe y exporta los
    dos archivos.
- **Estado**: COMPLETO en `10a6a51`.

### T3 — Deprecation notices en servicios viejos

- **Spec**: implícito (preparación para T4 que es downstream)
- **Files**:
  - `lib/core/sync/incremental_pull_sync_service.dart`
    (modified)
  - `lib/core/sync/incremental_push_sync_service.dart`
    (modified)
- **Approach**: agregar
  `@Deprecated('Use BidirectionalSyncService instead. Will
  be removed in a subsequent change.')` en cada clase.
- **Verify**:
  - `flutter analyze` no emite `error` ni `warning` por las
    deprecaciones (son `info`).
- **Estado**: COMPLETO en `10a6a51`.

## Verificación final

- `flutter analyze`: 0 issues.
- `flutter test`: 92/92 tests verdes (86 viejos + 6 nuevos
  del bidirectional).
- Coverage gate: `OK: 52.4% >= 50% umbral` sobre
  `lib/core/security/`.
- CI workflow `Flutter CI`: success.
- 2 commits en master con mensajes conventional.

## Lecciones aprendidas

- **`@internal` no aplica a clases públicas del mismo
  package**: el lint `invalid_internal_annotation` lo
  rechaza. Solo aplica a elementos privados (`_`) o dentro
  de `lib/src/`. La convención tiene que vivir en
  docstrings + barrel.
- **TDD funciona para servicios de infra complejos**: el
  `BidirectionalSyncService` tiene 5 requirements con
  múltiples scenarios cada uno. Escribir tests primero
  ayudó a clarificar la API antes de codear 767 líneas.
- **Prefix `pull*` / `push*` para parámetros específicos**:
  cuando un método aplica a un solo lado, el prefijo hace
  obvia la dirección. Por ejemplo, `pullCursor` vs
  `pushQueue`.
- **Deprecation notices en `info`, no en `warning`**: las
  deprecaciones no rompen CI por default. Esto permite
  migrar consumers gradualmente sin urgencia.

## Trabajo downstream (posterior, en otros changes)

- T4: migrar los dos consumers al nuevo servicio →
  `vaulta-sync-migration`.
- T5: borrar los servicios viejos cuando 0 references →
  parte de `vaulta-public-api-docs-extended`.
- Enforce real de "internal" via CI grep → change aparte
  si la convención se rompe en la práctica.
