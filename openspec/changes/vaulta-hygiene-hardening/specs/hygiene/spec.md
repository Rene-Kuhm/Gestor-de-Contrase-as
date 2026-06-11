# Spec: repo-hygiene

> Delta spec para la capability `repo-hygiene`.
> Forma parte del change `vaulta-hygiene-hardening`.

## Purpose

Garantizar que artefactos de build locales (APK, EXE, DMG) no puedan
ingresar accidentalmente al repositorio vía `git add`, y que la sección
"Licencia" del README refleje la licencia real del proyecto.

## Requirements

### REQ-HYG-001: Ignorar artefactos de build locales en la raíz

**Given** un binario de Android como `vaulta.apk`, `app-debug.apk` o
`app-release.apk` en la raíz del proyecto
**When** se ejecuta `git check-ignore -v <archivo>`
**Then** Git responde con un patrón matched de `.gitignore` que justifica
por qué se ignora.

#### Scenario: vaulta.apk queda ignorado

- **Given** el archivo `F:\Gestor-de-Contrase-as\vaulta.apk` existe (57 MB)
- **And** el `.gitignore` raíz contiene el patrón correspondiente
- **When** el desarrollador corre `git add vaulta.apk`
- **Then** Git reporta `The following paths are ignored by one of your
  .gitignore files`
- **And** el archivo NO entra al staging area.

#### Scenario: ignorar otros binarios comunes

- **Given** un binario `vaulta.exe` o `vaulta.dmg` cae en la raíz
- **When** se evalúa el `.gitignore`
- **Then** el patrón también lo cubre.

### REQ-HYG-002: README coherente con LICENSE

**Given** el archivo `LICENSE` declara MIT License (Copyright 2026 Rene Kuhm)
**When** un lector llega a la sección "Licencia" del `README.md`
**Then** la sección NO contradice al `LICENSE`
**And** menciona explícitamente la licencia MIT y a su titular.

#### Scenario: Sección Licencia del README referencia MIT

- **Given** el `LICENSE` en la raíz es MIT
- **When** se lee la sección "## Licencia" del `README.md` (líneas 204-206)
- **Then** el texto NO contiene la frase "Definir una licencia formal antes
  de aceptar contribuciones externas"
- **And** contiene una referencia a la licencia MIT (Copyright 2026 Rene Kuhm).

---

# Spec: lint-discipline

> Delta spec para la capability `lint-discipline`.

## Purpose

Endurecer `analysis_options.yaml` con reglas adicionales más allá del set
`flutter_lints` por defecto, adecuadas a un proyecto de seguridad donde la
disciplina de tipos y async correctness importa.

## Requirements

### REQ-LINT-001: Reglas mínimas endurecidas

**Given** el proyecto compila limpio con `flutter_lints` por defecto
(`flutter analyze` → 0 issues)
**When** se agregan reglas adicionales a `analysis_options.yaml`
**Then** las reglas agregadas son al menos:

- `prefer_const_constructors`
- `prefer_const_declarations`
- `unawaited_futures`
- `avoid_dynamic_calls`
- `public_member_api_docs` (limitado a `lib/core/` vía `analyzer.exclude` o
  `include` por paquete si es viable; si no, al menos activo global)

**And** `flutter analyze` sigue retornando 0 issues (o se documenta una
estrategia explícita de rollout si aparecen violaciones).

#### Scenario: analyze sigue limpio después del endurecimiento

- **Given** el código actual pasa `flutter analyze` con 0 issues
- **When** se actualiza `analysis_options.yaml` con las reglas de
  REQ-LINT-001
- **And** se ejecuta `flutter analyze`
- **Then** el comando termina con `No issues found!`
- **Or** el change documenta explícitamente la estrategia de rollout elegida
  (fix-in-place, // ignore_for_file, o warnings-only) y la aplica.

---

# Spec: test-coverage-gate

> Delta spec para la capability `test-coverage-gate`.

## Purpose

Que CI mida empíricamente la cobertura de tests del proyecto, con un
umbral mínimo en `lib/core/security/` (el corazón criptográfico del
proyecto).

## Requirements

### REQ-COV-001: Step de coverage en CI

**Given** el workflow `.github/workflows/flutter-ci.yml` corre en cada PR
**When** se agrega un step `flutter test --coverage` al job `analyze-test`
**Then** el step produce el archivo `coverage/lcov.info`
**And** un step posterior falla el job si la cobertura de
`lib/core/security/` cae bajo el umbral configurado.

#### Scenario: PR con cobertura suficiente pasa

- **Given** el umbral es 80% en `lib/core/security/`
- **When** un PR mantiene o sube la cobertura actual
- **Then** el step de coverage retorna exit code 0.

#### Scenario: PR que baja la cobertura del core falla

- **Given** el umbral es 80% en `lib/core/security/`
- **When** un PR introduce código en `lib/core/security/` sin tests
  correspondientes
- **Then** el step de coverage retorna exit code != 0
- **And** el job `analyze-test` falla.

### REQ-COV-002: Umbral configurable y conservador al inicio

**Given** no se conoce la cobertura actual empíricamente
**When** se elige el umbral inicial
**Then** el umbral es conservador (sugerencia: 70% en `lib/core/security/`,
sin umbral global) para no romper builds existentes en el primer run.

---

# Spec: widget-test-coverage

> Delta spec para la capability `widget-test-coverage`.

## Purpose

Cubrir con tests de widget las tres pantallas `presentation/` que hoy no
tienen archivo de test dedicado.

## Requirements

### REQ-WT-001: Tests para access, app_shell y sync_conflicts

**Given** existen 3 archivos presentation-level sin test dedicado:

- `lib/features/access/presentation/access_screen.dart`
- `lib/features/home/presentation/app_shell.dart`
- `lib/features/sync/presentation/sync_conflicts_sheet.dart`

**When** se crean los tests correspondientes en
`test/features/<feature>/presentation/`
**Then** cada archivo de test:

- Sigue el patrón de `test/features/vault/presentation/vault_dashboard_screen_test.dart`
  (fakes + in-memory services, no platform channels reales).
- Tiene al menos un `testWidgets` que ejercita el render del estado vacío o
  el path más común.
- Pasa con `flutter test`.

#### Scenario: AccessScreen testea el estado inicial

- **Given** un `VaultSecurityController` con `vaultSession == null`
- **And** un `VaultRepository` fake con 0 items
- **When** se renderiza `AccessScreen`
- **Then** el test verifica que aparece el título de la sección y el CTA de
  setup de autofill.

#### Scenario: AppShell testea la navegación

- **Given** un `AppShell` con tabs configuradas
- **When** se tapea el tab de Settings
- **Then** el test verifica que la vista de Settings se renderiza.

#### Scenario: SyncConflictsSheet testea la lista vacía

- **Given** un `SyncConflictsSheet` con 0 conflictos
- **When** se abre
- **Then** el test verifica que aparece el estado vacío localizado.
