# Spec: lint-discipline (extension)

> Modificacion a la capability `lint-discipline` de ADR-005.
> Agrega `public_member_api_docs` con scope limitado a `lib/core/`.

## Purpose

Forzar que toda API publica en `lib/core/` (security, sync, update)
tenga docstring. Las APIs en `lib/app/` y `lib/features/` quedan fuera
del scope de este change (pueden tener su propio follow-up).

## Requirements

### REQ-PAD-001: Regla activa solo en `lib/core/`

**Given** el `analysis_options.yaml` actual no activa
`public_member_api_docs`
**When** se actualiza con la regla + `analyzer.exclude`
**Then** la regla se aplica a `lib/core/**` y NO a `lib/app/**` ni
`lib/features/**`.

#### Scenario: dry-run en `lib/core/`

- **Given** la regla activa con `analyzer.exclude` cubriendo `lib/app`
  y `lib/features`
- **When** se corre `flutter analyze`
- **Then** las violaciones son solo en archivos de `lib/core/`.

### REQ-PAD-002: Docstrings consistentes

**Given** una API publica de `lib/core/` viola
`public_member_api_docs`
**When** se agrega un docstring
**Then** el docstring tiene:
- Primera linea: que hace la API (imperativo, < 80 chars).
- Segunda linea (si aplica): detalles sobre parametros notables,
  comportamiento, gotchas.
- Sin bloques de codigo decorativos.

#### Scenario: clase con responsabilidad clara

```dart
/// Calcula el strength score (0-100) de una contrasena.
///
/// Combina longitud, variedad de clases (lower/upper/digit/symbol) y
/// penaliza repeticiones. Usado por el strength meter del editor y por
/// el dashboard de metricas.
class PasswordStrengthEstimator { ... }
```

### REQ-PAD-003: Tests siguen pasando

**Given** el cambio no toca logica
**When** se corre `flutter test`
**Then** los 92 tests existentes siguen verde.

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
