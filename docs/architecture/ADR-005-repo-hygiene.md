# ADR-005: Hygiene de repositorio, lints y cobertura

- Estado: Aprobado
- Fecha: 2026-06-11

## Contexto

El proyecto Vaulta llega a su MVP publico (1.0.21) con criptografia solida,
arquitectura Clean y tests reales sobre el core. Sin embargo, el repositorio
tiene varias brechas de hygiene que no son bugs pero si deuda operativa:

1. `vaulta.apk` (57 MB) vive en la raiz del working tree, sin regla de
   `.gitignore` que lo cubra. Aunque hoy no esta trackeado por git
   (`git status` lo marca como untracked), un `git add .` distraido lo
   commitea.
2. La seccion "Licencia" del README contradice al archivo `LICENSE`
   real (MIT, Copyright 2026 Rene Kuhm).
3. El CI corre `flutter analyze` y `flutter test` en cada PR pero no mide
   cobertura, asi que "hay tests" es una afirmacion sin respaldo empirico.
4. `analysis_options.yaml` solo activa `package:flutter_lints/flutter.yaml`
   por defecto, sin endurecimiento adicional pese a ser una app de
   seguridad.
5. La capa `lib/core/sync/` esta sobredimensionada para algo etiquetado
   como experimental (ver ADR-004).
6. Faltan tests de widget para `access_screen`, `app_shell` y
   `sync_conflicts_sheet`.

## Decision

Se ejecuta el change `vaulta-hygiene-hardening` que cierra los seis
puntos con las siguientes politicas:

### Politica de artefactos locales

- `.gitignore` raiz ignora `/vaulta.apk`, `*.apk`, `*.aab`, `*.exe`,
  `*.dmg`, `*.pkg`, `*.msi`. Los artefactos de release viven en GitHub
  Releases, no en el repo.
- Si aparece un binario en la raiz, es un recordatorio de que algo se
  construyo localmente; no se commitea.

### Politica de documentacion de licencia

- El `LICENSE` en la raiz es la fuente de verdad.
- El README referencia al `LICENSE` y a la licencia MIT explicitamente.
- Cualquier cambio de licencia se hace primero en el archivo `LICENSE`
  y despues se actualiza el README; nunca al reves.

### Politica de lints

- Se agregan a `analysis_options.yaml`: `prefer_const_constructors`,
  `prefer_const_declarations`, `unawaited_futures`, `avoid_dynamic_calls`.
- **`public_member_api_docs` se difiere** al change
  `vaulta-public-api-docs` (follow-up). Razon: el baseline tiene ~739
  miembros publicos sin documentar en 50+ archivos, lo que excede el
  ambito de un rollout gradual. El follow-up limitara la regla a
  `lib/core/` (vía `analyzer.include`) y agregara documentacion por
  modulos en commits separados.
- **Estrategia de rollout: gradual con `// ignore_for_file:`**. Las
  reglas quedan activas inmediatamente. Las violaciones en archivos
  existentes se suprimen archivo por archivo con
  `// ignore_for_file: <rule_name>`. El codigo nuevo que toque esos
  archivos debe cumplir la regla; las supresiones nuevas se permiten
  solo si estan justificadas en un comentario adyacente.
- `flutter analyze` debe retornar 0 issues en cada PR.

### Politica de cobertura

- CI corre `flutter test --coverage` y genera `coverage/lcov.info`.
- Un script (`scripts/check_coverage.sh`) parsea el lcov, suma `LF`/`LH`
  para los archivos bajo `lib/core/security/`, y compara contra el umbral.
- **Umbral inicial: 50% en `lib/core/security/`** (2.4 puntos por debajo
  del baseline real medido en 2026-06-11, que es 52.4%). El baseline se
  registro en la implementacion de este change; ver tambien
  `coverage/lcov.info` post-merge.
- **Plan trimestral** (subir 5pp por trimestre, target 70% en Q2 2027):
  - Q3 2026 (jul-sep): 55%
  - Q4 2026 (oct-dic): 60%
  - Q1 2027 (ene-mar): 65%
  - Q2 2027 (abr-jun): 70%
- **Sin umbral global** en el primer corte. La cobertura de `lib/app/`
  (85%) y `lib/features/` (64.8%) es desigual; un umbral global
  bloquearia PRs legitimos. Foco en el core de seguridad primero.
- Las metricas de las demas areas (`lib/core/sync/`, `lib/core/update/`,
  `lib/app/`, `lib/features/`) se imprimen en el log del step para
  visibilidad, pero no bloquean.

### Politica de widget tests

- Toda pantalla en `lib/features/<x>/presentation/<screen>.dart` tiene
  al menos un `testWidgets` correspondiente en
  `test/features/<x>/presentation/<screen>_test.dart`.
- El patron a seguir es el de
  `test/features/vault/presentation/vault_dashboard_screen_test.dart`:
  fakes para servicios, in-memory storage, sin platform channels reales.

## Alternativas consideradas

- **No cerrar las brechas de hygiene ahora.** Descartado: el proyecto
  esta en release publico, y "release-ready con deuda visible" genera
  senales mezcladas a futuros contribuidores y reviewers.
- **Endurecer lints con fix-in-place total.** Descartado: el codebase
  tiene >50 archivos `.dart`; un PR con cientos de fixes mezcla la
  subida de reglas con la limpieza, dificulta la review y el rollback.
- **Coverage global desde el dia 1.** Descartado: forzaria exclusiones
  masivas (`// coverage:ignore-file`) en features con tests debiles,
  ensuciando el lcov con ruido. Mejor focalizar en el core primero.
- **Forzar el refactor de sync dentro de este change.** Descartado:
  mezclar hygiene con refactor de un subsistema vuelve el PR opaco.
  El refactor de sync se hace en su propio change
  (`vaulta-sync-surface-reduction`, ver ADR-004) una vez que este
  hygiene hardening este mergeado.

## Consecuencias / tradeoffs

- **Disciplina visible**: el proyecto pasa de "funciona" a "funciona y
  se puede medir / se mide".
- **Friccion minima en code review**: los `// ignore_for_file:` son
  senales explícitas de deuda que se revisan en cada PR.
- **Costo de mantenimiento del script de coverage**: bajo. Es un
  parser de lcov con un threshold hardcodeado.
- **Ritmo de convergencia al 85% de cobertura en el core**: depende de
  cadencia de PRs; se estima 2-3 trimestres con la politica gradual.

## Criterios de aceptacion verificables

- `git check-ignore -v vaulta.apk` retorna un patron matched de
  `.gitignore`.
- `git check-ignore -v vaulta.exe` retorna un patron matched.
- `flutter analyze` retorna `No issues found!` despues del endurecimiento
  con las 4 reglas activas y las supresiones aplicadas.
- El step de coverage esta en `.github/workflows/flutter-ci.yml` y se
  ejecuta en cada PR.
- `flutter test test/features/access/presentation/access_screen_test.dart`
  pasa.
- `flutter test test/features/home/presentation/app_shell_test.dart`
  pasa.
- `flutter test test/features/sync/presentation/sync_conflicts_sheet_test.dart`
  pasa.
- `docs/architecture/ADR-004-roadmap-sync.md` existe y referencia este
  ADR como prerequisito.
- `docs/architecture/ADR-005-repo-hygiene.md` (este archivo) esta
  indexado en `docs/architecture/README.md`.

## Implementacion por lotes

Este change (`vaulta-hygiene-hardening`) se ejecuta en una sola ronda.
El orden de tareas prioriza lo que NO tiene riesgo de romper el build:

- **Lote 1 (sin riesgo)**: T1 (`.gitignore`), T2 (README), T6 (este ADR),
  T7/T8/T9 (widget tests), T5 (ADR-004 sync).
- **Lote 2 (riesgo medio)**: T3 (lints) con dry-run previo de
  `flutter analyze` y supresiones graduadas.
- **Lote 3 (riesgo bajo)**: T4 (coverage step en CI) una vez que el
  umbral inicial esta calibrado contra la cobertura actual.
