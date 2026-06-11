# Tasks: vaulta-public-api-docs

## T1 — Activar la regla con scope + baseline de violaciones

- **Spec**: REQ-PAD-001
- **File**: `analysis_options.yaml`
- **Approach**: agregar `public_member_api_docs: true` al linter rules,
  agregar `analyzer.exclude` para `lib/app/**` y `lib/features/**`.
- **Verify**: `flutter analyze` lista violaciones SOLO en `lib/core/`.
- **Importante**: este commit NO incluye docstrings. Solo deja la
  regla activa con el scope correcto para que `git diff` de los
  siguientes commits muestre solo los docstrings nuevos.

## T2 — Docstrings en `lib/core/security/`

- **Spec**: REQ-PAD-002, REQ-PAD-003
- **Files**: 13 archivos en `lib/core/security/`
- **Approach**: dry-run con la regla activa, leer cada violacion,
  agregar docstring consistente. Iterar hasta `flutter analyze` 0
  issues.
- **Verify**: `git diff --stat lib/core/security/` muestra solo lineas
  que empiezan con `///`. `flutter analyze` 0 issues.

## T3 — Docstrings en `lib/core/sync/`

- **Spec**: REQ-PAD-002, REQ-PAD-003
- **Files**: 16 archivos en `lib/core/sync/` (incluye
  `bidirectional_sync_service.dart` y `sync_internal.dart` nuevos)
- **Approach**: mismo patron que T2.
- **Verify**: igual que T2.

## T4 — Docstrings en `lib/core/update/`

- **Spec**: REQ-PAD-002, REQ-PAD-003
- **File**: `lib/core/update/update_service.dart` (unico archivo)
- **Approach**: mismo patron que T2.
- **Verify**: igual que T2.

## Resumen de commits esperados

1. `chore(lint): activate public_member_api_docs scoped to lib/core/`
2. `docs(security): add public API docstrings`
3. `docs(sync): add public API docstrings`
4. `docs(update): add public API docstrings`

El commit 1 puede no ser necesario si T2-T4 ya cubren la activacion
(verificar al ejecutar).
