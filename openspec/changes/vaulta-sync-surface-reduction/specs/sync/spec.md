# Spec: bidirectional-sync

> Delta spec para la capability `bidirectional-sync`.

## Purpose

Reemplazar `IncrementalPullSyncService` y `IncrementalPushSyncService`
con un unico `BidirectionalSyncService` que:
- implementa `LocalVaultMutationSink` (recibe mutaciones locales),
- expone un lifecycle simple (`onSessionStarted`, `onAppResumed`,
  `runNow`, `pullNow`),
- mantiene internamente un cursor de pull persistido y una queue de push
  con backoff/retry/conflict.

## Requirements

### REQ-BS-001: Implementa LocalVaultMutationSink

**Given** una mutacion local (upsert o delete) llega al servicio
**When** se invoca `onLocalMutation(mutation)`
**Then** la mutacion se encola en la push queue con un `opId` UUID y
**And** se triggerea un push async sin bloquear la llamada.

#### Scenario: enqueue de upsert

- **Given** una `LocalVaultMutation.upsert` valida
- **When** `onLocalMutation` se invoca
- **Then** la push queue contiene 1 item con `kind=upsert` y
  `remoteRecordId` resuelto desde `localRecordId`.

### REQ-BS-002: Pull respeta cursor y throttle

**Given** existe un cursor persistido y un `lastPullAt` previo
**When** se invoca `onSessionStarted()`
**Then** si `now() - lastPullAt < throttleInterval` se omite el pull
**And** en caso contrario, se hace fetch desde el cursor persistido y se
avanza el cursor al ultimo `opCursor` aplicado.

#### Scenario: pull throttled

- **Given** `lastPullAt = T0`, `throttleInterval = 5min`, `now = T0+1min`
- **When** se invoca `onSessionStarted()`
- **Then** no se hace fetch; el cursor no se mueve.

#### Scenario: pull resumes from saved cursor

- **Given** cursor persistido = 5, lastPullAt fuera de throttle
- **And** el repositorio retorna 2 changes con `opCursor` 6 y 7
- **When** se invoca `onSessionStarted()`
- **Then** el fetch se hace con `afterOpId=5`
- **And** el cursor persistido final es 7.

### REQ-BS-003: Push queue drena con backoff exponencial

**Given** hay 1 item en la push queue
**When** se invoca `runNow()` (o el trigger desde una mutacion)
**Then** se intenta dispatch del item con la RPC remota
**And** si la respuesta es `applied` o `idempotentReplay`, el item se
remueve de la queue
**And** si la respuesta es `casConflict`, el item se marca como
`conflict` y se registra en `SyncConflictResolver`
**And** si la respuesta es transitoria, el item se reencola con
`retryCount++` y `nextAttemptAt = now + baseBackoff * 2^(retryCount-1)`.

#### Scenario: push applied

- **Given** 1 item encolado
- **And** el repositorio retorna `applied` con `appliedVersion=1`
- **When** se invoca `runNow()`
- **Then** la queue queda vacia
- **And** se persiste un snapshot con `version=1`.

#### Scenario: push cas conflict

- **Given** 1 item upsert encolado con `expectedVersion=3`
- **And** el repositorio retorna `casConflict` con `currentVersion=7`
- **When** se invoca `runNow()`
- **Then** el item se queda en la queue con `status=conflict`
- **And** se registra un `SyncConflictRecord` con el `localSnapshot` y
  el `remoteSnapshot`.

### REQ-BS-004: Pull tiene retry con backoff

**Given** el repositorio remoto lanza una excepcion transient
**When** `_fetchWithRetry` se ejecuta
**Then** se reintenta hasta `maxRetryAttempts` veces
**And** el delay entre intentos es `baseRetryDelay * 2^(attempt-1)`.

#### Scenario: pull retry recovers

- **Given** maxRetryAttempts=2
- **And** el primer fetch lanza `transient`
- **And** el segundo fetch retorna 1 change
- **When** se invoca `pullNow()`
- **Then** la queue se aplica 1 vez
- **And** el cursor avanza.

### REQ-BS-005: Diagnosticos se emiten para pull y push

**Given** el constructor recibe un `diagnosticsHook`
**When** hay un error transient, definitive, o un cas conflict
**Then** se llama `emitSyncDiagnostic` con `scope='pull'` o `scope='push'`
segun corresponda.

---

# Spec: sync-internal-export

## Requirements

### REQ-IE-001: `@internal` en APIs internas

**Given** `DeviceRegistrationRepository` y
`DeviceSessionRevocationService` son concerns de Supabase
**When** se observa su declaracion
**Then** llevan la anotacion `@internal` de `package:meta`
**And** su docstring explicita que son para uso interno de `lib/core/sync/`.

#### Scenario: DeviceRegistrationRepository marcado

- **Given** el archivo `lib/core/sync/device_registration_repository.dart`
- **When** se inspecciona la declaracion de la clase
- **Then** el archivo contiene `@internal` antes de la clase abstracta.

### REQ-IE-002: Export unico

**Given** las APIs internas existen en archivos separados
**When** se necesita exponerlas al resto de `lib/core/sync/`
**Then** se importa `sync_internal.dart` en lugar del archivo individual.

#### Scenario: sync_internal.dart existe

- **Given** `lib/core/sync/sync_internal.dart`
- **When** se lee su contenido
- **Then** exporta `device_registration_repository.dart` y
  `device_session_revocation_service.dart`.
