# Proposal: Vaulta hygiene hardening

## Intent

Cerrar seis brechas concretas de hygiene del proyecto Vaulta, todas con evidencia
verificada en código/configs:

1. Riesgo de `git add` accidental del binario `vaulta.apk` (57 MB) que vive en
   la raíz sin regla de ignore.
2. README línea 206 contradice al `LICENSE` real (MIT, Copyright 2026 Rene Kuhm).
3. CI no mide cobertura; no se puede afirmar empíricamente qué tan cubierto está
   el core de seguridad.
4. `analysis_options.yaml` solo activa `flutter_lints` por defecto; no hay
   endurecimiento adicional pese a ser una app de seguridad.
5. La capa `lib/core/sync/` (11 archivos) es grande para algo etiquetado
   "experimental"; la decisión de roadmap no está formalizada.
6. Faltan tests de widget para `access_screen`, `app_shell` y
   `sync_conflicts_sheet`.

No cambia comportamiento de la app para el usuario final. Cambia hygiene de
repositorio, CI, lints y cobertura de tests.

## Scope

### In Scope
- Editar `.gitignore` raíz para cubrir `*.apk` y binarios comunes de build
  locales.
- Reescribir la sección "Licencia" del README para apuntar al `LICENSE` MIT.
- Agregar step `flutter test --coverage` al workflow `flutter-ci.yml`, con
  umbral mínimo exigido vía script.
- Endurecer `analysis_options.yaml` con reglas adicionales.
- Documentar decisión de roadmap para la capa sync (ADR nuevo o nota en
  `docs/store-release-checklist.md`).
- Crear 3 archivos de test de widget siguiendo el patrón existente
  (fakes + in-memory services).

### Out of Scope
- Cambios en lógica de cifrado o de unlock.
- Cambios en el vault format (v2 sigue intacto).
- Refactor de la capa sync más allá de la decisión de roadmap.
- iOS/macOS/web (siguen en master-password only, no entran acá).
- Setup de OpenSpec/SDD a nivel repo (este change se monta ad-hoc en
  `openspec/changes/` y se archiva al cerrar).

## Capabilities

### New Capabilities
- `repo-hygiene`: reglas de ignore, README, y disciplina de no commitear
  artefactos de build locales.
- `test-coverage-gate`: cobertura medida en CI con umbral mínimo.
- `lint-discipline`: lints adicionales activos en `analysis_options.yaml`.
- `widget-test-coverage`: cobertura de widget tests para todas las pantallas
  presentation-level.

### Modified Capabilities
- `ci-pipeline` (implícita en `flutter-ci.yml`): agrega step de coverage.

## Approach

| Punto | Approach | Riesgo |
|---|---|---|
| 1 | Agregar `/vaulta.apk`, `*.apk`, `*.exe`, `*.dmg` a `.gitignore` raíz | Bajo |
| 2 | Reescribir sección Licencia del README; verificar que LICENSE apunte a MIT | Bajo |
| 3 | Step `flutter test --coverage` + script bash con umbral sobre `lcov.info` | Medio (umbral a definir) |
| 4 | Sumar reglas en `analysis_options.yaml` con estrategia **gradual** (`// ignore_for_file:` para violaciones existentes, regla exigida para código nuevo). **Nota**: `public_member_api_docs` se retir\u00f3 de este change por magnitud (739 violaciones en 50+ archivos) y queda como follow-up `vaulta-public-api-docs` | Alto (puede romper el build) |
| 5 | ADR-004-roadmap-sync.md con decisión explícita del usuario | Bajo (doc) |
| 6 | Tres archivos `*_test.dart` siguiendo `vault_dashboard_screen_test.dart` como template | Bajo |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `.gitignore` | Modified | +4 patrones de ignore |
| `README.md` | Modified | Sección Licencia reescrita |
| `.github/workflows/flutter-ci.yml` | Modified | +1 step de coverage |
| `analysis_options.yaml` | Modified | +N reglas de lint |
| `docs/architecture/ADR-004-roadmap-sync.md` | New | Decisión de roadmap sync |
| `test/features/access/presentation/access_screen_test.dart` | New | Widget test |
| `test/features/home/presentation/app_shell_test.dart` | New | Widget test |
| `test/features/sync/presentation/sync_conflicts_sheet_test.dart` | New | Widget test |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Lints nuevos rompen CI con muchas violaciones | Medium | Dry-run con `flutter analyze` antes; decidir rollout (ver pregunta bloqueante) |
| Umbral de coverage mal calibrado (muy alto bloquea, muy bajo no agrega valor) | Medium | Empezar con floor conservador en `lib/core/security/`, expandir gradualmente |
| Tests nuevos flaky por async/dependencias platforma | Low | Seguir patrón de fakes ya usado en `widget_test.dart` |
| El APK en root se commitea entre el merge y el próximo `git pull` | Low | Push inmediato del `.gitignore` actualizado |

## Rollback Plan

- `.gitignore`, `README.md`, `flutter-ci.yml`, `analysis_options.yaml`: revert
  del commit del change.
- ADRs: borrar archivo (no rompe nada).
- Tests nuevos: borrar archivos (no rompe nada; el resto del coverage se
  mantiene).

## Dependencies

- `flutter --version` confirmó 3.44.1 estable disponible.
- `dart` disponible en PATH. `lcov`/`genhtml` NO están instalados en el host
  Windows; el coverage usa el `lcov.info` crudo que produce `flutter test
  --coverage` y se valida por suma de líneas, no por HTML.

## Success Criteria

- [ ] `git check-ignore vaulta.apk` retorna el path.
- [ ] `flutter analyze` sigue limpio con las reglas nuevas (o se documenta
      estrategia de rollout si hay violaciones). `public_member_api_docs`
      queda diferido a `vaulta-public-api-docs`.
- [ ] CI corre `flutter test --coverage` y falla si la cobertura de
      `lib/core/security/` cae bajo el umbral.
- [ ] README sección Licencia referencia MIT correctamente.
- [ ] ADR-004-roadmap-sync.md existe y tiene una decisión binaria
      (promover / reducir / congelar).
- [ ] Los 3 tests de widget nuevos corren y pasan con `flutter test`.
