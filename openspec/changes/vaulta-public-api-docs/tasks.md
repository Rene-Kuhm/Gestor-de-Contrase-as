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
- **Estado**: **PARCIAL**. Archivos documentados (6 de 16):
  `sync_internal.dart`, `device_sync_bootstrap.dart`,
  `local_vault_mutation.dart`, `remote_vault_sync_repository.dart`,
  `supabase_device_registration_repository.dart`,
  `supabase_remote_vault_sync_repository.dart`. Archivos pendientes
  (~262 violaciones): `local_remote_vault_store.dart` (52),
  `device_registration_repository.dart` (40), `sync_conflict.dart`
  (35), `remote_vault_blob_change.dart` (29), `sync_runtime_hardening.dart`
  (29), `device_registration_service.dart` (26),
  `device_session_revocation_service.dart` (19),
  `incremental_pull_sync_service.dart` (8),
  `incremental_push_sync_service.dart` (8),
  `sync_conflict_resolver.dart` (8), `bidirectional_sync_service.dart`
  (6).
- **Desviacion documentada**: la severidad de `public_member_api_docs`
  se bajo a `info` (no `warning`) para no romper CI mientras la
  deuda de sync/ queda visible. Cuando se cierren los pendientes,
  restaurar `warning`.

## T4 — Docstrings en `lib/core/update/`

- **Spec**: REQ-PAD-002, REQ-PAD-003
- **File**: `lib/core/update/update_service.dart` (unico archivo)
- **Approach**: mismo patron que T2.
- **Estado**: COMPLETO. `flutter analyze lib/core/update/` retorna 0
  issues de `public_member_api_docs` para este archivo.

## Resumen de commits (los 3 que se hicieron)

1. `docs(security): add public API docstrings` (security/ + analisis)
2. `docs(core): add public API docstrings to sync and update subtrees`
3. `docs(adr): scaffold vaulta-public-api-docs change artifact`

## Trabajo downstream

- Cerrar las 262 violaciones de sync/. Estimado: 1 sesion
  enfocada, sin riesgo de regresion (los docstrings son additivos).
- Restaurar `public_member_api_docs: warning` en `analyzer.errors`
  una vez que `flutter analyze lib/core/sync/` reporte 0 issues.
- Considerar extender la regla a `lib/app/` y `lib/features/` en
  un follow-up aparte (con su propio scoping y plan gradual).
