# Tasks: vaulta-public-api-docs

## T1 — Activar la regla con scope + baseline de violaciones

- **Spec**: REQ-PAD-001
- **File**: `analysis_options.yaml`
- **Approach**: agregar `public_member_api_docs: true` al linter rules,
  agregar `analyzer.exclude` para `lib/app/**` y `lib/features/**`.
- **Verify**: `flutter analyze` lista violaciones SOLO en `lib/core/`.
- **Estado**: COMPLETO. Regla activa con scope `lib/core/**` y
  `analyzer.exclude` cubriendo `lib/app/**` y `lib/features/**`.
  Severidad: `info` (no `warning`) — ver desviacion T3.

## T2 — Docstrings en `lib/core/security/`

- **Spec**: REQ-PAD-002, REQ-PAD-003
- **Files**: 13 archivos en `lib/core/security/`
- **Approach**: dry-run con la regla activa, leer cada violacion,
  agregar docstring consistente. Iterar hasta `flutter analyze` 0
  issues.
- **Verify**: `git diff --stat lib/core/security/` muestra solo lineas
  que empiezan con `///`. `flutter analyze` 0 issues.
- **Estado**: COMPLETO. `flutter analyze lib/core/security/`
  retorna `No issues found!`.

## T3 — Docstrings en `lib/core/sync/`

- **Spec**: REQ-PAD-002, REQ-PAD-003
- **Files**: 16 archivos en `lib/core/sync/`
- **Approach**: mismo patron que T2.
- **Estado**: **COMPLETO**. Todos los 16 archivos tienen docstrings
  consistentes en sus miembros publicos. Archivos documentados
  (ordenados por tamano de la deuda): `local_remote_vault_store.dart`
  (52), `device_registration_repository.dart` (40),
  `sync_conflict.dart` (35), `remote_vault_blob_change.dart` (29),
  `sync_runtime_hardening.dart` (29),
  `device_registration_service.dart` (26),
  `device_session_revocation_service.dart` (19),
  `incremental_pull_sync_service.dart` (8),
  `incremental_push_sync_service.dart` (8),
  `sync_conflict_resolver.dart` (8),
  `bidirectional_sync_service.dart` (6), y los 6 que ya estaban
  completos del commit anterior.
- **Notas**: en `incremental_push_sync_service.dart` se agrego
  `// ignore_for_file: depend_on_referenced_packages` para
  silenciar el lint de `meta` (mismo patron que
  `bidirectional_sync_service.dart`).

## T4 — Docstrings en `lib/core/update/`

- **Spec**: REQ-PAD-002, REQ-PAD-003
- **File**: `lib/core/update/update_service.dart` (unico archivo)
- **Approach**: mismo patron que T2.
- **Estado**: COMPLETO. `flutter analyze lib/core/update/` retorna 0
  issues de `public_member_api_docs` para este archivo.

## Resumen de commits

1. `docs(security): add public API docstrings` (security/ + cambio a
   `info` severity)
2. `docs(core): add public API docstrings to sync and update subtrees`
   (sub-subarbol sync/, archivo unico update/)
3. `docs(adr): scaffold vaulta-public-api-docs change artifact`
4. (Este commit) `docs(sync): add public API docstrings to remaining
   sync files` + restaurar `public_member_api_docs: warning`.

## Estado final

- `flutter analyze` retorna `No issues found!` con la regla activa
  como `warning` y todos los docstrings en su lugar.
- `flutter test` pasa 92/92.
- Coverage gate sigue verde (52.4% en `lib/core/security/`).
- La regla se enforcea desde el proximo PR: cualquier API publica
  nueva en `lib/core/**` sin docstring rompe CI.

## Trabajo downstream

- Considerar extender la regla a `lib/app/` y `lib/features/` en
  un follow-up aparte (con su propio scoping y plan gradual, dado
  que la deuda actual alli es mucho mayor que en `lib/core/`).
