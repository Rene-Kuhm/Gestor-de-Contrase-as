# Tasks: vaulta-public-api-docs

> Change cerrado. Los 4 commits principales del plan se
> aplicaron en orden, más 2 commits de scaffolding de los
> artifacts. Severidad final: `warning`. CI retorna success,
> 92 tests verdes, coverage gate verde.

## Estado: COMPLETO (2026-06-11)

## Commits del change (en orden cronológico)

| # | Commit | Mensaje | Cubre |
|---|--------|---------|-------|
| 1 | `69b4291` | `docs(security): add public API docstrings` | T1 (security), activación inicial con `info` |
| 2 | `7312114` | `docs(core): add public API docstrings to sync and update subtrees` | T2 (sync + update) |
| 3 | `c3c2f8e` | `docs(adr): scaffold vaulta-public-api-docs change artifact` | Scaffolding |
| 4 | `1459f20` | `docs(adr): reflect partial state of vaulta-public-api-docs` | tasks.md update |
| 5 | `fad7adc` | `docs(sync): add public API docstrings to remaining sync files` | T2 (resto de sync) |
| 6 | `2b32dd8` | `chore(lint): restore public_member_api_docs warning severity and mark change complete` | T3 (restore warning) |

## Tasks por spec

### T1 — Activar la regla con scope + docstrings en `lib/core/security/`

- **Spec**: REQ-PAD-001, REQ-PAD-002, REQ-PAD-003
  (subsección `lib/core/security/`)
- **Files**: 13 archivos en `lib/core/security/`,
  `analysis_options.yaml`
- **Approach**:
  - Agregar `public_member_api_docs: true` a `linter.rules`.
  - Agregar `analyzer.exclude` para `lib/app/**` y
    `lib/features/**`.
  - Severidad inicial: `info` (no `warning`) para
    dimensionar la deuda sin romper CI.
  - Dry-run con la regla activa, leer cada violación, agregar
    docstring consistente. Iterar hasta `flutter analyze` 0
    issues.
- **Verify**:
  - `flutter analyze lib/core/security/` retorna
    `No issues found!`.
  - `git diff --stat lib/core/security/` muestra solo líneas
    que empiezan con `///`.
- **Estado**: COMPLETO en `69b4291`.

### T2 — Docstrings en `lib/core/sync/` y `lib/core/update/`

- **Spec**: REQ-PAD-002, REQ-PAD-003 (subsecciones
  `lib/core/sync/` y `lib/core/update/`)
- **Files**: 16 archivos en `lib/core/sync/`, 1 archivo en
  `lib/core/update/update_service.dart`
- **Approach**: mismo patrón que T1. Iterar hasta 0 issues
  con `flutter analyze lib/core/sync/ lib/core/update/`.
- **Archivos documentados en `lib/core/sync/`** (ordenados
  por tamaño de la deuda):
  - `local_remote_vault_store.dart` (52)
  - `device_registration_repository.dart` (40)
  - `sync_conflict.dart` (35)
  - `remote_vault_blob_change.dart` (29)
  - `sync_runtime_hardening.dart` (29)
  - `device_registration_service.dart` (26)
  - `device_session_revocation_service.dart` (19)
  - `incremental_pull_sync_service.dart` (8)
  - `incremental_push_sync_service.dart` (8)
  - `sync_conflict_resolver.dart` (8)
  - `bidirectional_sync_service.dart` (6)
  - y los 5 archivos que ya estaban completos del commit
    anterior.
- **Gotcha**: `incremental_push_sync_service.dart` requirió
  `// ignore_for_file: depend_on_referenced_packages` para
  silenciar el lint de `meta` (mismo patrón que
  `bidirectional_sync_service.dart`).
- **Verify**:
  - `flutter analyze lib/core/sync/ lib/core/update/`
    retorna 0 issues de `public_member_api_docs`.
- **Estado**: COMPLETO en `7312114` (grueso) + `fad7adc`
  (resto).

### T3 — Restaurar `warning` y cerrar el change

- **Spec**: REQ-PAD-004
- **File**: `analysis_options.yaml`
- **Approach**:
  - Cambiar `public_member_api_docs: info` a
    `public_member_api_docs: warning` en
    `analysis_options.yaml`.
  - Actualizar `tasks.md` con el estado final y los
    success criteria cumplidos.
- **Verify**:
  - `flutter analyze` retorna 0 issues con la severidad
    `warning`.
  - `flutter test` pasa 92/92.
  - Coverage gate sigue en `OK: 52.4% >= 50%`.
  - La regla se enforcea desde el próximo PR.
- **Estado**: COMPLETO en `2b32dd8`.

## Verificación final

- `flutter analyze`: `No issues found!` con la regla activa
  como `warning` y todos los docstrings en su lugar.
- `flutter test`: 92/92 tests verdes.
- Coverage gate: `OK: 52.4% >= 50% umbral` sobre
  `lib/core/security/`.
- CI workflow `Flutter CI`: success.
- 6 commits en master (4 principales + 2 de scaffolding)
  con mensajes conventional.

## Lecciones aprendidas

- **Activación con `info` severity es útil para dimensionar
  deuda sin romper CI**: permite iterar sobre docstrings
  sin que CI parpadee rojo. Al final, con la deuda cerrada,
  se restaura a `warning` en un commit aparte.
- **Rollout por subfolder (security/ → sync/ + update/)**:
  cada commit es reviewable independientemente, con scope
  acotado.
- **El `// ignore_for_file: depend_on_referenced_packages`**
  es un patrón conocido en este proyecto (se usa en
  `bidirectional_sync_service.dart`,
  `incremental_push_sync_service.dart`). No es deuda, es
  patrón intencional para dependencias transitivas.
- **El lint no exige docstrings en overrides**: miembros
  heredados de `Object` (==, hashCode, toString) no
  requieren docs.

## Trabajo downstream (posterior, en otros changes)

- Extender la regla a `lib/app/` y `lib/features/`. Esto
  es `vaulta-public-api-docs-extended`, donde primero se
  cierran los 276 docstrings por subárbol y luego se
  reactiva la regla con scope `lib/**`.
