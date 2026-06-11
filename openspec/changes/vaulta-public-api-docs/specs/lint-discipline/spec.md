# Spec: lint-discipline (lib/core scope)

> Delta spec para el change `vaulta-public-api-docs`.

## Purpose

Activar la regla `public_member_api_docs` limitada a
`lib/core/**` (mediante `analyzer.exclude`) y agregar
docstrings consistentes a las APIs públicas de los subfolders
`security/`, `sync/` y `update/`. Cualquier contribuidor que
agregue una API pública en `lib/core/` sin documentar rompe
CI.

## Requirements

### REQ-PAD-001: La regla aplica a `lib/core/**`

**Given** `analysis_options.yaml` configura
`public_member_api_docs: warning` en `linter.rules` y excluye
`lib/app/**` y `lib/features/**` en `analyzer.exclude`
**When** se ejecuta `flutter analyze`
**Then** la regla inspecciona todo archivo bajo `lib/core/`
**And** no afecta archivos bajo `lib/app/` ni `lib/features/`
en este change.

#### Scenario: analyze inspecciona solo `lib/core/`

- **Given** el `analysis_options.yaml` con scope `lib/core/**`
- **When** se ejecuta `flutter analyze`
- **Then** retorna 0 issues
- **And** ningún archivo bajo `lib/app/` o `lib/features/`
  aparece en la salida

#### Scenario: agregar un miembro público sin docstring en `lib/core/` rompe CI

- **Given** un nuevo miembro público en cualquier archivo
  bajo `lib/core/`
- **When** se commitea sin `///` docstring
- **Then** `flutter analyze` lo reporta como `warning` con
  exit code 1
- **And** el CI falla

#### Scenario: agregar un miembro público sin docstring en `lib/app/` no rompe CI en este change

- **Given** un nuevo miembro público en `lib/app/`
- **When** se commitea sin `///` docstring
- **Then** `flutter analyze` no lo reporta (la regla está
  excluida por `analyzer.exclude`)
- **And** CI pasa
- **Note**: este comportamiento cambia en
  `vaulta-public-api-docs-extended`.

### REQ-PAD-002: Estilo consistente de docstrings

**Given** los 30 archivos bajo `lib/core/{security,sync,update}/`
requieren docstrings
**When** se agregan
**Then** siguen la plantilla:

```
/// <Qué hace la API en una línea>.
///
/// <Detalles: parámetros notables, comportamiento, relaciones
/// con otras APIs, gotchas>. Usar bloques de código solo si
/// ayudan.
```

**And** los docstrings son 1-3 líneas para APIs simples, hasta
8 líneas para APIs con varios parámetros o behaviors.

#### Scenario: clase pública tiene docstring de clase + ctor

- **Given** una clase con un constructor público
- **When** se documenta
- **Then** la clase tiene un `///` block arriba de la
  declaración de la clase
- **And** el constructor tiene su propio `///` block arriba
  de la firma

#### Scenario: campo público tiene docstring

- **Given** un `final` o `var` público en una clase
- **When** se documenta
- **Then** el campo tiene un `///` line que describe su rol
  semántico (no solo su tipo)

### REQ-PAD-003: La deuda se cierra por subfolder

**Given** el baseline del 2026-06-11 mide docstrings faltantes
en ~30 archivos de `lib/core/{security,sync,update}/`
**When** se aplican los 3 commits de Fase 2
**Then** los 30 archivos tienen 100% de miembros públicos
documentados
**And** `flutter analyze lib/core/` retorna 0 issues de
`public_member_api_docs`.

#### Scenario: `lib/core/security/` sin violations

- **Given** el commit `69b4291` aplicado
- **When** se ejecuta `flutter analyze lib/core/security/`
- **Then** retorna `No issues found!` para los 13 archivos

#### Scenario: `lib/core/sync/` + `lib/core/update/` sin violations

- **Given** los commits `7312114` y `fad7adc` aplicados
- **When** se ejecuta `flutter analyze lib/core/sync/ lib/core/update/`
- **Then** retorna `No issues found!` para los 17 archivos

### REQ-PAD-004: Severidad final es `warning`

**Given** la activación inicial de la regla fue con
`public_member_api_docs: info` para dimensionar la deuda sin
romper CI
**And** la deuda se cerró en los 3 commits de Fase 2
**When** se aplica el commit `2b32dd8`
**Then** la severidad en `analysis_options.yaml` se restaura
a `warning`
**And** la regla queda enforceada para código nuevo.

#### Scenario: la regla rompe CI para código nuevo

- **Given** `analysis_options.yaml` con
  `public_member_api_docs: warning`
- **When** un nuevo miembro público en `lib/core/` se
  commitea sin docstring
- **Then** `flutter analyze` retorna exit code 1
- **And** el CI workflow `Flutter CI` falla en el step
  `analyze-test`
