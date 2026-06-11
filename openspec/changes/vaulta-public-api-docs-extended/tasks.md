# Tasks: vaulta-public-api-docs-extended

## Estado: ROLLBACK (este change revierte la activación)

Este change fue creado con la intención de extender
`public_member_api_docs` a `lib/app/` y `lib/features/`. La
activación se hizo, pero **rompió CI** porque `flutter analyze`
retorna exit code 1 con 276 violaciones `info`. Mi suposición
original ("info no falla el build") era incorrecta.

**Este commit revierte la activación** y deja la propuesta como
downstream para una sesión futura, una vez que la deuda de las
276 violaciones este cerrada.

### T1 — Revertir la activación

- **Spec**: REQ-PAD-001 (extension)
- **File**: `analysis_options.yaml`
- **Approach**: volver el `analyzer.exclude` a incluir
  `lib/app/**` y `lib/features/**`. Cambiar
  `public_member_api_docs: info` a
  `public_member_api_docs: warning`.
- **Verify**: `flutter analyze` retorna `No issues found!` con
  exit code 0.
- **Estado**: COMPLETO. Local verificado.

### Baseline medido durante la ventana de activación (2026-06-11)

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

**`lib/features/` — 12 archivos, 124 violaciones**

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

**Total: 276 violaciones en 20 archivos.**

### T2 — Plan downstream (no en este change, queda para futuras sesiones)

Para reactivar la regla, primero cerrar las 276 violaciones. El
plan queda documentado en el proposal:

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
4. **Commit 4: `chore(lint): reactivate public_member_api_docs for
   all lib`** — quitar `lib/app/**` y `lib/features/**` del
   `analyzer.exclude` y subir a `warning`. Ahora si, con 0
   violaciones en todo `lib/`, CI queda verde.

### Lección aprendida

- **No extender una regla lint a un scope donde hay deuda
  visible sin cerrar la deuda primero o sin un mecanismo
  intermedio de suppressión.** `flutter analyze` cuenta `info`
  como issue y retorna exit code 1, lo cual rompe CI sin que
  parezca obvio.
- El approach correcto sería haber agregado
  `// ignore_for_file: public_member_api_docs` a cada archivo
  de `lib/app/` y `lib/features/` ANTES de activar la regla, o
  haber extendido la regla usando
  `analyzer.exclude` con un archivo por carpeta (patron
  incremental).
- La sugerencia original de ADR-005 era esta: "agregar
  documentacion por modulos en commits separados". Este
  approach se sigue aplicando — la activación es el último
  commit, no el primero.