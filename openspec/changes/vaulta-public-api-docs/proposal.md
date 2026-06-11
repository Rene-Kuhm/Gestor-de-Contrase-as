# Proposal: vaulta-public-api-docs

> Implementacion del follow-up de ADR-005 (Politica de lints: el item
> "public_member_api_docs se difiere" se levanta aca).

## Intent

Activar el lint `public_member_api_docs` limitado a `lib/core/`
(mediante `analyzer.exclude` del resto del proyecto) y agregar
docstrings a todas las APIs publicas que el lint considere
subdocumentadas. Resultado: cualquier contribuidor que agregue una API
publica en `lib/core/` sin documentar rompe CI.

Referencia: `docs/architecture/ADR-005-repo-hygiene.md` seccion
"Politica de lints".

## Scope

### In Scope
- Activar `public_member_api_docs` en `analysis_options.yaml` con
  `analyzer.exclude` que cubra todo lo que NO sea `lib/core/`.
- Docstrings consistentes (1-3 lineas, que digan **que** y **por que**,
  no solo el nombre reescrito) en las APIs publicas de:
  - `lib/core/security/` (13 archivos)
  - `lib/core/sync/` (16 archivos, incluye el nuevo
    `bidirectional_sync_service.dart` y `sync_internal.dart`)
  - `lib/core/update/` (1 archivo, `update_service.dart`)
- Tres commits separados, uno por subfolder, para que cada uno sea
  reviewable.

### Out of Scope
- Docstrings en `lib/app/` o `lib/features/` (la regla solo aplica a
  `lib/core/`).
- Refactor de APIs (no se cambian firmas, solo se documentan).
- Activacion de otras reglas (`depend_on_referenced_packages` ya esta
  manejada con `// ignore_for_file:` cuando aplica).

## Capabilities

### Modified Capabilities
- `lint-discipline` (de ADR-005): se agrega la regla
  `public_member_api_docs` con `analyzer.exclude` por scope.

## Approach

### Fase 1: activar la regla con scope

```yaml
# analysis_options.yaml
analyzer:
  errors:
    public_member_api_docs: warning
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/app/**"
    - "lib/features/**"
```

Esto deja la regla activa solo para `lib/core/**`.

### Fase 2: docstrings por subfolder

Tres commits independientes, mismo patron:

1. **Commit 1**: `docs(security): add public API docstrings` cubre los
   13 archivos de `lib/core/security/`.
2. **Commit 2**: `docs(sync): add public API docstrings` cubre los 16
   archivos de `lib/core/sync/`.
3. **Commit 3**: `docs(update): add public API docstrings` cubre
   `lib/core/update/update_service.dart`.

Estilo de docstrings (consistente en los 3 commits):

```dart
/// <Que hace la API en una linea>.
///
/// <Detalles: parametros notables, comportamiento, relaciones con
/// otras APIs, gotchas>. Usar bloques de codigo solo si ayudan.
```

### Fase 3: verificar

- `flutter analyze` retorna 0 issues.
- `flutter test` pasa (86 + N tests, sin cambios funcionales).
- Coverage gate sigue verde (52.4% en `lib/core/security/`).
- `git ls-files lib/core/` muestra los archivos modificados con su
  docstring nuevo.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `analysis_options.yaml` | Modified | +`public_member_api_docs` +`analyzer.exclude` |
| `lib/core/security/*.dart` (13 files) | Modified | +docstrings |
| `lib/core/sync/*.dart` (16 files) | Modified | +docstrings |
| `lib/core/update/update_service.dart` | Modified | +docstrings |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| El baseline de violaciones es muy alto (>500) y el PR queda opaco | Medium | Split en 3 commits por subfolder |
| Docstrings inconsistentes entre archivos | Medium | Plantilla fija (ver Approach Fase 2) |
| El `analyzer.exclude` rompe algo por path matching | Low | Probar con `flutter analyze` despues de aplicar |
| `public_member_api_docs` exige documentar miembros heredados | Low | El lint no pide override de docs en overrides (verificar con dry-run) |

## Rollback Plan

- Revert de los 3 commits (separados, faciles de identificar).
- `analysis_options.yaml` vuelve a la version sin la regla.

## Dependencies

- `flutter analyze` 3.x o superior (soportado, ya en uso).

## Success Criteria

- [ ] `flutter analyze` retorna 0 issues tras activar la regla y agregar
      todos los docstrings.
- [ ] `flutter test` pasa (>= 92 tests, sin cambios funcionales).
- [ ] Coverage gate sigue en `OK: 52.4% >= 50%`.
- [ ] `git diff --stat lib/core/` muestra cambios solo de docstrings
      (lineas que empiezan con `///`), no de logica.
- [ ] Tres commits en master, uno por subfolder, con mensajes
      conventional.
