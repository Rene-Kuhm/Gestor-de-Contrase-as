# Tasks: vaulta-sync-surface-reduction

## T1 — Crear BidirectionalSyncService + tests TDD

- **Specs**: REQ-BS-001..005
- **Files**: new `lib/core/sync/bidirectional_sync_service.dart`, new
  `test/core/sync/bidirectional_sync_service_test.dart`
- **Approach**: TDD. Escribir tests primero (Red), implementar (Green),
  refactor.
- **Verify**: `flutter test test/core/sync/bidirectional_sync_service_test.dart`
  pasa. Los tests viejos (`incremental_pull_sync_service_test.dart`,
  `incremental_push_sync_service_test.dart`) siguen pasando porque sus
  servicios no cambian.
- **Estado**: no requiere decision del usuario (el diseno viene de
  ADR-004).

## T2 — Marcado interno + sync_internal.dart

- **Specs**: REQ-IE-001, REQ-IE-002
- **Files**: modified `lib/core/sync/device_registration_repository.dart`,
  modified `lib/core/sync/device_session_revocation_service.dart`, new
  `lib/core/sync/sync_internal.dart`
- **Approach**: docstrings explicitos en cada interfaz declarando que es
  para uso interno de `lib/core/sync/`. Crear el barrel
  `sync_internal.dart` que re-exporta ambas declaraciones.
- **Desviacion documentada**: la propuesta original de usar la
  anotacion `@internal` de `package:meta` **no se ejecuta**. El lint
  `invalid_internal_annotation` la rechaza: `@internal` solo aplica a
  elementos privados del package (símbolos con `_` o dentro de
  `lib/src/`). Como ambas clases son publicas por diseno de la API, la
  convencion queda en (a) docstrings que explican el contrato, (b) el
  barrel `sync_internal.dart` como punto unico de re-export. La
  enforcement real (CI grep + lint custom) queda para un follow-up
  dedicado si la convention se rompe en la practica.
- **Verify**: `grep -r 'Features must not import' lib/core/sync/`
  matchea. `flutter analyze` 0 issues. `lib/core/sync/sync_internal.dart`
  existe y exporta los dos archivos.

## T3 — Deprecation notices en servicios viejos

- **Specs**: implicit (preparacion para T4 que es downstream)
- **Files**: modified `lib/core/sync/incremental_pull_sync_service.dart`,
  modified `lib/core/sync/incremental_push_sync_service.dart`
- **Approach**: agregar `@Deprecated('Use BidirectionalSyncService
  instead. Will be removed in a subsequent change.')` en cada clase.
- **Verify**: `flutter analyze` no emite `error` ni `warning` por las
  deprecaciones (son `info`).
