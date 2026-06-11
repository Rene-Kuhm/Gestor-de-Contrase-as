# Tasks: vaulta-hygiene-hardening

> Implementation tasks for the change `vaulta-hygiene-hardening`.
> Each task lists its BDD scenario(s) from `specs/hygiene/spec.md` and its
> TDD evidence expectation (Red → Green → Refactor).

## Task ordering

T1, T2, T6 son safe (sin riesgo de romper el build). T3, T4, T5 tienen
dependencias o requieren decisiones del usuario. T7 y T8 son tests nuevos
que pueden correr en cualquier momento.

---

## T1 — Ignorar artefactos de build en `.gitignore`

- **Spec**: REQ-HYG-001
- **Scenario**: "vaulta.apk queda ignorado", "ignorar otros binarios comunes"
- **Files**: `.gitignore` (root)
- **Change**: agregar `/vaulta.apk`, `*.apk`, `*.exe`, `*.dmg`
- **TDD evidence (BDD scenario as test)**:
  - **Red**: `git check-ignore -v vaulta.apk` retorna exit code 1
  - **Green**: tras el cambio, retorna el patrón matched y exit code 0
- **Verify**: `git check-ignore -v vaulta.apk; git check-ignore -v vaulta.exe`

## T2 — Corregir sección Licencia del README

- **Spec**: REQ-HYG-002
- **Scenario**: "Sección Licencia del README referencia MIT"
- **Files**: `README.md` (líneas 204-206)
- **Change**: reescribir la sección para referenciar MIT (Copyright 2026 Rene
  Kuhm) y eliminar la frase obsoleta sobre "definir licencia formal".
- **TDD evidence**: no aplica (es doc). Verificación manual + `grep` que
  confirme ausencia de la frase obsoleta.
- **Verify**: `Select-String -Path README.md -Pattern "Definir una licencia formal"` → vacío.

## T3 — Endurecer `analysis_options.yaml` (BLOQUEANTE: requiere decisión)

- **Spec**: REQ-LINT-001
- **Scenario**: "analyze sigue limpio después del endurecimiento"
- **Files**: `analysis_options.yaml`
- **Change**: agregar `prefer_const_constructors`, `prefer_const_declarations`,
  `unawaited_futures`, `avoid_dynamic_calls`. **`public_member_api_docs` se
  difiere** a un change aparte (`vaulta-public-api-docs`) por magnitud
  (739 violaciones en 50+ archivos no es gradual).
- **Estrategia de rollout (decidida por el usuario)**: **gradual con
  `// ignore_for_file:`**. Las reglas quedan activas inmediatamente. Las
  violaciones existentes en archivos ya commiteados se suprimen archivo por
  archivo con `// ignore_for_file: <rule_name>`. El código nuevo que toque
  esos archivos debe cumplir la regla (o agregar la misma supresión solo si
  es estrictamente necesario y queda justificada en el comentario).
- **TDD evidence (BDD scenario as test)**:
  - **Red**: dry-run agregando las reglas y corriendo `flutter analyze`.
    Listar las violaciones resultantes para dimensionar la deuda.
  - **Green**: agregar `// ignore_for_file: <rule>` en los archivos
    afectados con un comentario breve que justifique la deuda. Re-correr
    `flutter analyze` y exigir 0 issues.
  - **Refactor**: abrir tareas hijas por archivo para limpiar las
    supresiones en commits posteriores.
- **Verify**: `flutter analyze` → 0 issues después de la supresiones.
- **Estado**: BLOQUEANTE RESUELTO — estrategia confirmada.
- **Ejecutado**: 14 archivos con `// ignore_for_file:` (4 reglas distintas).
  `flutter analyze` retorna `No issues found! (ran in 3.4s)` y `EXIT_CODE: 0`.
- **Desviación documentada**: `public_member_api_docs` (739 violaciones)
  retirado y diferido a `vaulta-public-api-docs`.

## T4 — Step de coverage en CI con umbral

- **Spec**: REQ-COV-001, REQ-COV-002
- **Scenarios**: "PR con cobertura suficiente pasa", "PR que baja la
  cobertura del core falla"
- **Files**: `.github/workflows/flutter-ci.yml`, nuevo
  `scripts/check_coverage.sh` (o `.ps1` para parity con Windows host).
- **Change**: agregar step `flutter test --coverage` + step que valida
  `coverage/lcov.info` con umbral 70% inicial en `lib/core/security/`.
- **TDD evidence (BDD scenarios as tests)**:
  - **Red**: el step no existe, no hay validación.
  - **Green**: agregar step + script. Medir baseline con
    `flutter test --coverage` localmente, calibrar umbral.
  - **Refactor**: si el script queda acoplado a path absoluto, abstraer.
- **Verify**: script retorna exit code 0 con la cobertura actual; CI lo
  ejecuta en cada PR.
- **Ejecutado**: `scripts/check_coverage.sh` validado con 3 umbrales (50/55/100).
  Baseline real `lib/core/security/`: 52.4% (532/1015 lineas en 13 archivos).
  Script retorna exit 0 con 50%, exit 1 con 55% (atraparia regresion).
  Bug encontrado y corregido: awk usaba `$2 + 0` cuando el formato lcov
  es `LF:N` con `:` no espacio; fixed a `substr($0, 4) + 0`.

## T5 — ADR-004: decisión de roadmap para la capa sync

- **Spec**: implícito (no aparece en `specs/hygiene/spec.md` porque es
  decisión de governance, no de comportamiento testeable).
- **Files**: nuevo `docs/architecture/ADR-004-roadmap-sync.md`
- **Decisión del usuario**: **(b) Reducir superficie**.
- **Scope de este change** (lo que SÍ se hace acá):
  - Crear el ADR-004 documentando la decisión, las alternativas
    descartadas y el rationale.
  - Listar explícitamente las tareas downstream (consolidación de
    `incremental_pull`/`incremental_push`, marcado de
    `device_registration_*` como `@internal`) como follow-up, no como
    trabajo de este change.
- **Scope que NO se hace acá**:
  - No se refactoriza código de `lib/core/sync/` en este change. Eso es
    un change aparte (`vaulta-sync-surface-reduction`) que se abrirá
    después de mergear este hygiene hardening.
- **TDD evidence**: N/A (ADR). Verificación: el ADR existe, tiene fecha,
  estado (Aprobado), alternativas descartadas con motivo y referencia a
  las tareas downstream.
- **Estado**: BLOQUEANTE RESUELTO — estrategia confirmada.

## T6 — ADR menor + nota: registrar este change

- **Spec**: implícito.
- **Files**: nuevo `docs/architecture/ADR-005-repo-hygiene.md` (corto, una
  página).
- **Change**: dejar registro de por qué se decidió el rollout de lints, el
  umbral de coverage y la regla de gitignore. Buena práctica de governance.

## T7 — Widget test: AccessScreen ✅

- **Spec**: REQ-WT-001
- **Scenario**: "AccessScreen testea el estado inicial"
- **Files**: `test/features/access/presentation/access_screen_test.dart`
- **TDD**: Red → Green → Refactor.
- **Verificado**: test pasa (86/86 verde). Necesito viewport 1080x4000 para
  que el boton "Lock vault now" sea visible (esta debajo del fold por default).
  Gotcha: `AppSectionHeader` aplica `.toUpperCase()` al eyebrow
  (`"Autofill & access"` se renderiza como `"AUTOFILL & ACCESS"`).

## T8 — Widget test: AppShell ✅

- **Spec**: REQ-WT-001
- **Scenario**: "AppShell testea la navegación"
- **Files**: nuevo `test/features/home/presentation/app_shell_test.dart`
- **TDD**: Red → Green → Refactor.
- **Verify**: `flutter test test/features/home/presentation/app_shell_test.dart`

## T9 — Widget test: SyncConflictsSheet ✅

- **Spec**: REQ-WT-001
- **Scenario**: "SyncConflictsSheet testea la lista vacía"
- **Files**: `test/features/sync/presentation/sync_conflicts_sheet_test.dart`
- **TDD**: Red → Green → Refactor.
- **Verificado**: test pasa. Usa `showSyncConflictsSheet` (API publica) con
  un fake resolver que retorna lista vacia. Verifica el empty state
  localizado ("Sync conflicts" + "No pending conflicts. Everything is in sync.").
- **Gotcha**: la clase `_SyncConflictsSheet` es privada; el test dispara
  la API publica (`showSyncConflictsSheet`) en lugar de instanciar directo.

---

## Estado final del change

- **9 tasks ejecutadas**: T1-T9 completas.
- **Tests**: 86 verde (eran 83, +3 nuevos).
- **Analyze**: 0 issues.
- **Coverage gate**: 52.4% en `lib/core/security/`, umbral 50% OK.
- **Sigue siendo revisable**: nada se commitea sin tu OK.

---

## Resumen de bloqueantes

| Task | Bloqueante | Por qué |
|---|---|---|
| T3 | Resuelto | Estrategia elegida: gradual con `// ignore_for_file:` |
| T5 | Sí | Decisión de roadmap sync (3 opciones con tradeoffs reales) |
| Resto | No | Procedimiento estándar, evidencia clara |

T1, T2, T6, T7, T8, T9 pueden arrancar en paralelo apenas se confirmen las
decisiones de T3 y T5 (o sin ellas, ya que no dependen).
