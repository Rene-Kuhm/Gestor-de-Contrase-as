# ADR-002: Modelo de sincronizacion con versionado, CAS, idempotencia y tombstones

- Estado: Aprobado
- Fecha: 2026-03-23

## Contexto

La sincronizacion E2E con Supabase requiere evitar sobrescrituras silenciosas, duplicados por reintentos y reaparicion de datos borrados. Se necesita un contrato determinista para clientes moviles con conectividad intermitente.

## Decision

Se congela un modelo de sync orientado a consistencia optimista:

1. Versionado por registro: cada secreto tiene `version` monotona creciente por usuario.
2. CAS (Compare-And-Set): update/delete exige `expected_version`; si no coincide, retorna conflicto.
3. Idempotencia por mutacion: cada operacion de escritura via API usa `idempotency_key` (UUID) para deduplicar reintentos.
4. Tombstones: los borrados son logicos (`deleted_at` + `version`) y se sincronizan igual que updates.
5. Upsert controlado: crear/editar usa llaves estables por entidad (`record_id`) y validacion de ownership via RLS.
6. Reconciliacion cliente: pull incremental por `updated_at`/cursor + resolucion de conflicto explicita en cliente.

## Alternativas consideradas

- Last-write-wins sin CAS: simple pero propenso a perdida silenciosa de cambios.
- Bloqueos pesimistas server-side: mayor complejidad y peor UX offline.
- Hard delete inmediato: rompe convergencia multi-dispositivo y recuperacion de estado.

## Consecuencias / tradeoffs

- Confiabilidad: se minimiza corrupcion por carreras y reintentos.
- Complejidad: sube el costo de backend y cliente por manejo de conflictos.
- Almacenamiento: tombstones aumentan volumen hasta politica de purge.
- UX: el usuario puede ver conflictos explicitos en escenarios concurrentes.

## Criterios de aceptacion verificables

- Un update con `expected_version` desactualizada devuelve conflicto verificable.
- Repetir la misma mutacion con igual `idempotency_key` no duplica ni reescribe resultados.
- Un delete en un dispositivo llega a los demas como tombstone y no reaparece tras sync.
- El pull incremental reproduce estado convergente en dos clientes con orden distinto de eventos.

## Implementacion por lotes

- Batch S1: definir schema SQL/RLS de versionado, tombstones e idempotency log.
- Batch S2: exponer RPC/API con CAS e idempotencia, incluyendo codigos de conflicto.
- Batch S3: integrar engine de sync cliente (cola local, retry seguro, resolucion de conflicto).
