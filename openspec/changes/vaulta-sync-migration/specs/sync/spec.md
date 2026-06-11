# Spec: bidirectional-sync (consumer migration)

> Delta spec para la migration T4 de ADR-004.

## Purpose

Migrar los dos consumers de los servicios viejos de sync
(`IncrementalPullSyncService` + `IncrementalPushSyncService`) al
nuevo `BidirectionalSyncService`. Cierra el estado transitorio del
sync layer.

## Requirements

### REQ-MIG-001: `device_sync_bootstrap.dart` usa `BidirectionalSyncService`

**Given** `buildDeviceSyncLifecycle` necesita construir todos los
servicios de sync para el lifecycle
**When** se ejecuta (con `SUPABASE_URL` + `SUPABASE_ANON_KEY`)
**Then** crea una sola instancia de `BidirectionalSyncService`
**And** el `SyncConflictResolver` recibe `syncService.runNow` como
`triggerPushSync`
**And** el `RelayLocalVaultMutationSink` se ata a `syncService`
**And** el `DeviceSyncLifecycle` recibe el `syncService` como un
solo param.

#### Scenario: bootstrap construye un solo sync service

- **Given** SUPABASE_URL y SUPABASE_ANON_KEY están definidas
- **When** se llama a `buildDeviceSyncLifecycle(...)`
- **Then** retorna un `DeviceSyncLifecycle` con un `syncService`
  no-nulo (el bidirectional)
- **And** el `conflictResolver` está cableado a `syncService.runNow`

### REQ-MIG-002: `DeviceSyncLifecycle` toma un solo `syncService`

**Given** el lifecycle necesita invocar pull + push en sus hooks
de session/resume
**When** se construye
**Then** toma un solo param opcional `syncService:
BidirectionalSyncService?`
**And** NO toma `pullSyncService` ni `pushSyncService` separados.

#### Scenario: lifecycle invoca syncService.onSessionStarted

- **Given** un lifecycle con un `syncService` mock
- **When** se llama a `lifecycle.onSessionStarted()`
- **Then** `syncService.onSessionStarted()` es invocado exactamente
  1 vez (que internamente corre pull + push)

#### Scenario: lifecycle invoca syncService.onAppResumed

- **Given** un lifecycle con un `syncService` mock y ya registrado
- **When** se llama a `lifecycle.onAppResumed()`
- **Then** `syncService.onAppResumed()` es invocado exactamente
  1 vez

### REQ-MIG-003: Servicios viejos sin consumers

**Given** la migracion se completa
**When** se hace `git grep "pullSyncService\|pushSyncService"` en
`lib/`
**Then** retorna 0 resultados (los servicios viejos quedan
existiendo como `@Deprecated` pero sin importadores).

#### Scenario: los servicios viejos son inalcanzables desde `lib/`

- **Given** la migracion mergeada
- **When** se busca `IncrementalPullSyncService` o
  `IncrementalPushSyncService` como tipo en archivos bajo `lib/`
- **Then** no se encuentran referencias (los archivos viejos se
  referencian a si mismos y a tests, pero no son usados por
  ningun consumer)