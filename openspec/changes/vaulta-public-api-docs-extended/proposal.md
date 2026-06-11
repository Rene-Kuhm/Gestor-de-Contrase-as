# Proposal: vaulta-public-api-docs-extended

> Extiende `public_member_api_docs` (ya activo en `lib/core/`
> desde `vaulta-public-api-docs`) a `lib/app/` y `lib/features/`.

## Intent

Cerrar la deuda de documentacion que sigue afuera de `lib/core/`.
El lint ya esta activo y funcional con scope `lib/core/`. Este
change lo extiende para que cubra todo `lib/`, dejando al
equipo cerrar la deuda gradualmente con la misma regla que ya
estan usando en el core.

Resultado esperado:
- La regla `public_member_api_docs` aplica a TODO `lib/**` (no
  solo a `lib/core/`).
- Severidad `info` (no `warning`) porque la deuda en
  `lib/app/` + `lib/features/` es mucho mayor que en `lib/core/`
  y no queremos romper el build.
- Baseline medido y documentado en la propuesta.
- Tareas downstream explícitas para cerrar la deuda por subfolder.

## Scope

### In Scope
- Modificar `analysis_options.yaml` para que `public_member_api_docs`
  cubra `lib/app/` y `lib/features/` ademas de `lib/core/`. Severidad
  inicial: `info`.
- Medir el baseline de violaciones con `flutter analyze`.
- Documentar la deuda en este change (sin agregar docstrings;
  eso es trabajo downstream).

### Out of Scope
- Agregar docstrings a `lib/app/` y `lib/features/`. Estimacion
  honesta: ~300-500 docstrings, es un sprint aparte. Solo lo dejo
  planeado.
- Cambios en la logica de la app o de las features.
- Extender la regla a `test/` (los tests son privados al paquete
  de test, no necesitan docstrings publicos).

## Capabilities

### Modified Capabilities
- `lint-discipline` (de ADR-005): la regla ahora cubre TODO `lib/`.

## Approach

### Fase 1: extender el scope

Cambios en `analysis_options.yaml`:
- Quitar `lib/app/**` y `lib/features/**` del `analyzer.exclude`.
- Mantener `public_member_api_docs: info` (NO `warning` todavia).

### Fase 2: medir el baseline

Ejecutar `flutter analyze` y contar violaciones por subfolder
para dimensionar la deuda. Esperado: `lib/app/` con docstrings
parciales ya que lo documente parcialmente en sesiones previas
(probablemente ~50-100 violaciones), y `lib/features/` con mas
deuda (~200-400 violaciones, dado que la mayoria de las
pantallas no tienen docstrings en sus componentes publicos).

### Fase 3: documentar el plan downstream

Lista de tareas en `tasks.md` para que el equipo vaya cerrando la
deuda por subfolder, similar a como se cerro `lib/core/sync/`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `analysis_options.yaml` | Modified | Quitar exclusiones de `lib/app/**` y `lib/features/**` |
| `lib/app/`, `lib/features/` | Unchanged en este change | Las docstrings se agregan en cambios downstream |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| El baseline de violaciones es muy alto y bloquea el output de analyze | Low | La severidad es `info`, no `warning`. Las violaciones aparecen pero no fallan el build. |
| La regla genera ruido que el equipo ignora | Low | ADR-005 ya establecio que la regla es opt-in al cleanup por folder. El equipo cerro `lib/core/sync/` siguiendo el plan, asi que hay precedente. |
| Hay APIs publicas de `lib/app/` o `lib/features/` que no deberian documentarse (ej. widgets privados exportados) | Low | Si surge, se agregan `// ignore_for_file:` o `// ignore:` puntuales. Lo mismo que se hizo en `lib/core/`. |

## Rollback Plan

Revertir `analysis_options.yaml` para volver a excluir
`lib/app/**` y `lib/features/**`. Sin data corruption.

## Success Criteria

- [ ] `flutter analyze` lista violaciones en `lib/app/` y
      `lib/features/` ademas de las de `lib/core/`.
- [ ] La salida sigue siendo `No issues found!` solo si todas las
      violaciones son `info` (sin `error` ni `warning`).
- [ ] Coverage gate sigue verde.
- [ ] `tasks.md` lista la deuda por subfolder con estimacion.

## Trabajo downstream (no en este change)

- Cerrar las ~50-100 violaciones de `lib/app/` en 1 commit.
- Cerrar las ~200-400 violaciones de `lib/features/` en 2-3 commits
  (un commit por feature group: vault/, security/, settings/, sync/).
- Restaurar `public_member_api_docs: warning` en
  `analysis_options.yaml` una vez que el total sea 0.
- Considerar extender la regla a otros lints utiles (ej.
  `document_ignores`, `comment_references`).

## Estimacion de la deuda (a confirmar con dry-run)

| Subfolder | Archivos | Violaciones estimadas |
|-----------|----------|------------------------|
| `lib/app/design_system/` | 3 | ~20 |
| `lib/app/theme/` | 2 | ~30 |
| `lib/app/localization/` | 2 | ~15 |
| `lib/app/bootstrap/` | 1 | ~5 |
| `lib/features/access/` | 1 | ~5 |
| `lib/features/home/` | 1 | ~10 |
| `lib/features/security/` | 1 | ~10 |
| `lib/features/settings/` | 2 | ~30 |
| `lib/features/sync/` | 1 | ~5 |
| `lib/features/vault/` | 5 | ~200 |
| **Total estimado** | **19** | **~330** |