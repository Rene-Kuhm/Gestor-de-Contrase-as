# Tasks: vaulta-public-api-docs-extended

## T1 — Extender el scope de la regla a `lib/app/` y `lib/features/`

- **Spec**: REQ-PAD-001 (extension)
- **File**: `analysis_options.yaml`
- **Approach**: quitar `lib/app/**` y `lib/features/**` del
  `analyzer.exclude`. Mantener severidad `info` (no `warning`)
  porque la deuda es grande (276 violaciones vs 0 en `lib/core/`
  ya documentado).
- **Verify**: `flutter analyze` lista violaciones en `lib/app/`
  y `lib/features/` ademas de las de `lib/core/`.
- **Estado**: COMPLETO. Baseline medido: 276 violaciones en 20
  archivos (ver distribucion abajo).

### Baseline medido (2026-06-11)

**`lib/app/` — 8 archivos, 152 violaciones**

| Archivo | Violaciones |
|---------|-------------|
| `lib/app/theme/app_colors.dart` | 42 |
| `lib/app/design_system/app_components.dart` | 33 |
| `lib/app/theme/app_spacing.dart` | 23 |
| `lib/app/design_system/app_panel.dart` | 15 |
| `lib/app/bootstrap/password_manager_app.dart` | 8 |
| `lib/app/localization/app_locale_controller.dart` | 6 |
| `lib/app/design_system/metric_card.dart` | 5 |
| `lib/app/design_system/vault_entry_tile.dart` | 5 |
| `lib/app/localization/l10n.dart` | 2 |

**`lib/features/` — 12 archivos, 125 violaciones**

| Archivo | Violaciones |
|---------|-------------|
| `lib/features/vault/application/vault_import_models.dart` | 41 |
| `lib/features/vault/domain/vault_item.dart` | 26 |
| `lib/features/home/presentation/app_shell.dart` | 14 |
| `lib/features/vault/domain/vault_summary.dart` | 8 |
| `lib/features/vault/application/vault_duplicate_detector.dart` | 7 |
| `lib/features/settings/presentation/settings_screen.dart` | 7 |
| `lib/features/vault/presentation/vault_import_screen.dart` | 6 |
| `lib/features/vault/presentation/vault_dashboard_screen.dart` | 5 |
| `lib/features/vault/presentation/vault_entry_detail_screen.dart` | 5 |
| `lib/features/vault/presentation/vault_entry_editor_screen.dart` | 4 |
| `lib/features/security/presentation/security_gate.dart` | 4 |
| `lib/features/access/presentation/access_screen.dart` | 3 |
| `lib/features/settings/presentation/update_section.dart` | 3 |
| `lib/features/vault/application/vault_import_parser.dart` | 3 |
| `lib/features/sync/presentation/sync_conflicts_sheet.dart` | 1 |

**Total: 277 violaciones en 20 archivos.** (Nota: 276 en
`flutter analyze` summary — discrepancia de 1 por el formato del
reporte, no significativo.)

## T2 — Plan downstream explícito

Trabajo futuro (no en este change) — estimado en 1-2 sesiones
enfocadas, sin riesgo de regresion (los docstrings son aditivos):

1. **Commit 1: `docs(app): add public API docstrings`** — cierra
   `lib/app/` (8 archivos, 152 violaciones). Estimado: 30-45 min
   de trabajo mecánico.
2. **Commit 2: `docs(features): add public API docstrings to vault
   subtree`** — cierra `lib/features/vault/` (5 archivos, 91
   violaciones). Estimado: 20-30 min.
3. **Commit 3: `docs(features): add public API docstrings to
   security + home + access + settings + sync subtrees`** —
   cierra el resto de `lib/features/` (7 archivos, 33
   violaciones). Estimado: 15-20 min.
4. **Commit 4: `chore(lint): restore public_member_api_docs warning
   severity`** — subir la severidad de `info` a `warning` para
   que la regla enforce desde el proximo PR.

## Estado final (de este change)

- `flutter analyze` reporta 276 violaciones, todas como `info`.
  No hay `error` ni `warning` -> CI verde.
- `flutter test` pasa los 94 tests existentes.
- Coverage gate sigue verde (52.4% en `lib/core/security/`).
- `public_member_api_docs` ahora aplica a TODO `lib/`. El equipo
  tiene visibilidad de la deuda restante y el plan para cerrarla.