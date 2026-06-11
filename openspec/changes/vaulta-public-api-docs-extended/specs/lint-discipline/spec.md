# Spec: lint-discipline (scope expansion)

> Delta spec para el change `vaulta-public-api-docs-extended`.

## Purpose

Extender el scope de la regla `public_member_api_docs` (activa
en `lib/core/` desde `vaulta-public-api-docs`) a todo `lib/**`,
justificando las supresiones intencionales que sobreviven
(design tokens) y dejando la deuda de 276 docstrings cerrada
con un patrón consistente.

## Requirements

### REQ-LINT-001: La regla aplica a todo `lib/**`

**Given** la regla `public_member_api_docs` está activa con
severidad `warning` (ADR-005)
**When** se ejecuta `flutter analyze`
**Then** la regla inspecciona todo archivo bajo `lib/` (no solo
`lib/core/`)
**And** `analyzer.exclude` solo contiene `**/*.g.dart` y
`**/*.freezed.dart`.

#### Scenario: analyze limpia todo `lib/` sin exclusiones por subfolder

- **Given** `analysis_options.yaml` con el scope expandido
- **When** se ejecuta `flutter analyze`
- **Then** retorna `No issues found!` con exit code 0
- **And** no se reportan exclusiones por subfolder de aplicación
  en la salida

#### Scenario: agregar un miembro público sin docstring rompe CI

- **Given** un nuevo miembro público en cualquier archivo bajo
  `lib/`
- **When** se commitea sin `///` docstring
- **Then** `flutter analyze` lo reporta como `warning` con exit
  code 1
- **And** el CI falla

### REQ-LINT-002: Design tokens usan suppression justificada

**Given** los archivos `app_colors.dart` (42 violaciones) y
`app_spacing.dart` (23 violaciones) son design tokens donde cada
constante está nombrada por su rol semántico y agrupada bajo
secciones `// ---`
**And** ADR-005 prohíbe extender la regla a design tokens
**When** se evalúan estos archivos
**Then** contienen `// ignore_for_file: public_member_api_docs` con
un comentario previo de >=5 líneas que justifica la supresión
**And** la justificación nombra explícitamente ADR-005.

#### Scenario: app_colors.dart tiene suppression justificada

- **Given** el archivo `lib/app/theme/app_colors.dart`
- **When** se lee el header
- **Then** las primeras líneas son un bloque de comentario
  explicando por qué se aplica la suppression
- **And** la línea final del header es
  `// ignore_for_file: public_member_api_docs`
- **And** el comentario menciona ADR-005 por nombre

#### Scenario: app_spacing.dart tiene suppression justificada

- **Given** el archivo `lib/app/theme/app_spacing.dart`
- **When** se lee el header
- **Then** contiene el mismo patrón de suppression justificada
  que `app_colors.dart`

### REQ-LINT-003: Estilo consistente de docstrings

**Given** los 18 archivos no-suprimidos bajo `lib/app/` y
`lib/features/` requieren docstrings
**When** se agregan
**Then** siguen la plantilla:

```
/// <Qué hace la API en una línea>.
///
/// <Detalles: parámetros notables, comportamiento, relaciones con
/// otras APIs, gotchas>. Usar bloques de código solo si ayudan.
```

**And** los docstrings son 1-3 líneas para APIs simples, hasta 8
líneas para APIs con varios parámetros o behaviors.

#### Scenario: clase pública tiene docstring de clase + constructor

- **Given** una clase con un constructor público
- **When** se documenta
- **Then** la clase tiene un `///` block arriba de la declaración
  de la clase
- **And** el constructor tiene su propio `///` block arriba de la
  firma

#### Scenario: campo público tiene docstring

- **Given** un `final` o `var` público en una clase
- **When** se documenta
- **Then** el campo tiene un `///` line que describe su rol
  semántico (no solo su tipo)

### REQ-LINT-004: La deuda de 276 docstrings se cierra

**Given** el baseline medido el 2026-06-11 documenta 276
violaciones distribuidas en 20 archivos
**When** se aplican los 4 commits del change
**Then** los 18 archivos no-suprimidos tienen 100% de miembros
públicos documentados
**And** los 2 archivos suprimidos (design tokens) tienen la
suppression con justificación.

#### Scenario: `lib/app/` sin violations

- **Given** los 8 archivos de `lib/app/` con el change aplicado
- **When** se ejecuta `flutter analyze` con la regla expandida
- **Then** `lib/app/` reporta 0 violations
- **And** el output de analyze no menciona ninguno de los archivos
  de `lib/app/` como problemático

#### Scenario: `lib/features/` sin violations

- **Given** los 14 archivos de `lib/features/` con el change
  aplicado
- **When** se ejecuta `flutter analyze` con la regla expandida
- **Then** `lib/features/` reporta 0 violations

### REQ-LINT-005: El coverage gate no queda en el borde del 50%

**Given** el coverage gate (`scripts/check_coverage.sh`) verifica
que `lib/core/security/` tenga >=50% de cobertura
**And** el cambio de scope de la regla no agrega ni quita tests
**And** el baseline del 2026-06-11 mide 49.7% (debajo del
umbral) en algunas corridas
**When** se completa el change
**Then** se agrega un test comprehensivo para
`AesGcmVaultCryptoService` y `VaultSession` que cubre 11 branches
**And** la cobertura queda en 50.7% estable.

#### Scenario: crypto service y vault session tienen tests directos

- **Given** el archivo
  `test/core/security/aes_gcm_vault_crypto_service_test.dart`
- **When** se ejecuta `flutter test`
- **Then** contiene >=5 tests para `AesGcmVaultCryptoService`
  cubriendo: encrypt v1, decrypt v1, encrypt v2, decrypt v2,
  version inválida, keyId mismatch, secretKey inválido
- **And** contiene >=4 tests para `VaultSession` cubriendo:
  factory v1, factory v2, kdf vacío, dekWrap vacío

#### Scenario: coverage estable en al menos 50%

- **Given** los tests del cambio aplicados
- **When** se corre `flutter test --coverage && bash scripts/check_coverage.sh`
  3 veces consecutivas
- **Then** cada corrida retorna `OK: 50.7% >= 50% umbral` (o
  superior, nunca por debajo de 50%)
