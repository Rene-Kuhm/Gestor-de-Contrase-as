# Proposal: vaulta-sync-surface-reduction

> Implementacion de ADR-004 (Roadmap de `lib/core/sync/`).
> Forma parte de la fase "S4" del plan trimestral del ADR-004.

## Intent

Reducir la superficie de `lib/core/sync/` de 15 archivos a ~6-7 archivos,
consolidando los dos servicios de sync incremental en uno solo
bidireccional, y marcando los concerns internos como tales.

Referencia: `docs/architecture/ADR-004-roadmap-sync.md` seccion "Decision"
y "Implementacion por lotes".

## Scope

### In Scope
- Crear `lib/core/sync/bidirectional_sync_service.dart` que consolida
  `IncrementalPullSyncService` + `IncrementalPushSyncService`.
- Tests del nuevo servicio (TDD Red→Green→Refactor).
- Marcar `DeviceRegistrationRepository` y `DeviceSessionRevocationService`
  con `@internal` (anotacion de `package:meta`).
- Crear `lib/core/sync/sync_internal.dart` que exporta las APIs internas.
- Agregar `@Deprecated('Use BidirectionalSyncService instead.')` en los
  dos servicios viejos.
- **NO** se migran los consumidores todavia (eso es T4, separado, segun
  ADR-004).
- **NO** se borran los archivos viejos en este change.

### Out of Scope
- Migrar `device_sync_bootstrap.dart` y `DeviceSyncLifecycle` al nuevo
  servicio (T4, segun ADR-004).
- Borrar `incremental_pull_sync_service.dart` y
  `incremental_push_sync_service.dart` (T4).
- Cambios en el formato del vault o en el cifrado.
- Activar la regla `public_member_api_docs` (eso es `vaulta-public-api-docs`).

## Capabilities

### New Capabilities
- `bidirectional-sync`: servicio unico que reemplaza pull + push
  incrementales con una sola pieza de codigo.

### Modified Capabilities
- `sync-internal-export`: export unico `sync/sync_internal.dart` para
  concerns de sync que las features no deberian importar.

## Approach

### T1: `BidirectionalSyncService`
- API: `implements LocalVaultMutationSink` (recibe mutaciones locales).
- Lifecycle: `onSessionStarted()`, `onAppResumed()`, `runNow()` (trigger
  explicito para el conflict resolver), `pullNow({bool force = false})`.
- Estado interno:
  - Pull: cursor persistido, `lastPullAt` para throttle.
  - Push: queue persistida, flag `_running` + `_rerunRequested`.
- Parametros con prefijo `pull*` o `push*` para claridad cuando aplica a
  uno solo de los dos lados.
- TDD: tests para happy path pull, happy path push, retry con backoff,
  conflict detection, throttle de pull, queue mutation, mutex de push.

### T2: `@internal` + export
- Agregar `import 'package:meta/meta.dart';` y `@internal` en
  `DeviceRegistrationRepository` y `DeviceSessionRevocationService`.
- Docstring explicito: "Solo para uso interno de `lib/core/sync/`. Las
  features deben usar `LocalDeviceIdentityService` y las APIs publicas."
- Crear `lib/core/sync/sync_internal.dart` que exporta ambos.
- La enforcement real es por convencion + CI grep, no por analyzer (el
  paquete `gestor_contrasenas` es un solo package, no multiples, asi que
  `@internal` no bloquea imports intra-package).

### T3: deprecation notices
- `@Deprecated('Use BidirectionalSyncService instead. Will be removed in a '
    'subsequent change.')` en las dos clases viejas.
- Las deprecaciones aparecen como `info` (no fallan el build).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/core/sync/bidirectional_sync_service.dart` | New | Servicio consolidado |
| `lib/core/sync/sync_internal.dart` | New | Export unico de APIs internas |
| `test/core/sync/bidirectional_sync_service_test.dart` | New | Tests TDD del nuevo servicio |
| `lib/core/sync/device_registration_repository.dart` | Modified | +docstring de "internal"; sin `@internal` (ver riesgos) |
| `lib/core/sync/device_session_revocation_service.dart` | Modified | +docstring de "internal"; sin `@internal` (ver riesgos) |
| `lib/core/sync/incremental_pull_sync_service.dart` | Modified | +`@Deprecated` |
| `lib/core/sync/incremental_push_sync_service.dart` | Modified | +`@Deprecated` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| API del nuevo servicio rompe consumidores cuando migren (T4) | Low | Tests exhaustivos en este change; el T4 los ejercita en contexto real |
| `@internal` no se enforce en mismo package | High (por diseno) | Documentado en ADR-004; enforcement es por CI grep en follow-up |
| Deprecation warnings saturan el log de CI | Low | Las deprecaciones son `info` por default, no aparecen en errores |
| Tests viejos del pull/push fallen porque sus archivos cambian | Low | Solo agrego `@Deprecated`, no cambio semantica |

## Rollback Plan

- `git revert` del merge commit.
- Los 2 archivos viejos (`incremental_pull_sync_service.dart`,
  `incremental_push_sync_service.dart`) vuelven a no tener `@Deprecated`.
- El nuevo archivo `bidirectional_sync_service.dart` queda como codigo
  muerto (compila, pasa tests, pero no se usa) — cleanup trivial.

## Dependencies

- `package:meta` para `@internal` (ya viene transitivamente, pero se
  importa explicitamente).
- Flutter estable (sin cambios de SDK).

## Success Criteria

- [ ] `flutter analyze` retorna 0 issues (las deprecaciones son `info`).
- [ ] `flutter test` pasa (86 tests existentes + nuevos del bidirectional).
- [ ] `git ls-files lib/core/sync/ | wc -l` queda en 17 (15 viejos + 2
      nuevos). Bajara cuando T4 borre los viejos.
- [ ] `grep -r 'Features must not import' lib/core/sync/` matchea en
      ambos archivos marcados (convencion por docstring; `@internal`
      no aplica a clases publicas del mismo package).
- [ ] `lib/core/sync/sync_internal.dart` existe y exporta las dos APIs
      internas.
- [ ] Los consumidores actuales (`device_sync_bootstrap.dart`,
      `DeviceSyncLifecycle`) siguen funcionando con los servicios
      viejos.
