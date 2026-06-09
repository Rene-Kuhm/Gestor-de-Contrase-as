# Supabase migrations (B1 + B2 + B3 + B7A)

This project now includes an initial Supabase schema for zero-knowledge sync.

## Files

- `supabase/migrations/20260323100000_initial_vault_schema.sql`
- `supabase/migrations/20260323113000_add_vault_sync_rpc.sql`
- `supabase/migrations/20260323153000_add_device_registration_rpc.sql`
- `supabase/migrations/20260323183000_add_device_revocation_rpc.sql`

## What these migrations create

- Tables: `vault_devices`, `vault_blobs`, `vault_ops`
- Indexes for owner + sync query patterns
- `updated_at` trigger helper (`public.set_updated_at`)
- RLS enabled and forced on all three tables
- Owner-only RLS policies (`auth.uid() = user_id`) for select/insert/update/delete
- RPC functions for sync writes with CAS + idempotency:
  - `public.rpc_vault_upsert_blob(...)`
  - `public.rpc_vault_delete_blob(...)`
- RPC functions for device presence (Batch B3):
  - `public.rpc_vault_register_device(...)`
  - `public.rpc_vault_device_heartbeat(...)`
- Session controls and revocation RPC (Batch B7A):
  - `public.rpc_vault_device_access_status(...)`
  - `public.rpc_vault_list_devices()`
  - `public.rpc_vault_revoke_device(...)`
  - `public.rpc_vault_revoke_all_other_devices(...)`
  - `public.vault_session_controls` (`revoke_all_after` per user)

## RPC behavior (Batch B2)

- Both RPCs run inside a single SQL transaction.
- Both require authenticated context (`auth.uid()`) and registered `device_id`.
- Idempotency is keyed by `(auth.uid(), idempotency_key)` via `vault_ops`.
- If `idempotency_key` is reused with a different payload, result is `idempotency_mismatch`.
- If `expected_version` does not match current row version, result is `cas_conflict`.
- Every effective mutation writes an entry in `vault_ops` with `applied_version`.

## Device registration behavior (Batch B3)

- `vault_devices` now stores `platform` and `app_version` metadata.
- `rpc_vault_register_device` performs idempotent upsert per `(auth.uid(), device_id)`.
- `rpc_vault_device_heartbeat` updates `last_seen_at` and refreshes basic metadata.
- Both RPCs accept `p_last_seen_at`; if omitted, they use `now()`.
- Both RPCs are granted to `authenticated` and return a structured result row.

High-level flow in app wiring:

1. App startup resolves a persistent `device_id` from secure storage (creates one if absent).
2. After local session unlock, app calls `rpc_vault_register_device`.
3. On foreground resume, app sends `rpc_vault_device_heartbeat` with throttle (5 minutes).
4. Full sync pipeline (pull/push conflict loop) remains for later batch.

## Session revocation flow (Batch B7A)

1. On unlock/session start, Flutter runs `rpc_vault_device_access_status` before register/heartbeat.
2. If status is revoked (`revoked_device` or `revoked_all`), client triggers security action and blocks sync.
3. If allowed, client continues with register or heartbeat and normal sync lifecycle.
4. Device management uses `rpc_vault_list_devices` for status, `rpc_vault_revoke_device` for single device, and `rpc_vault_revoke_all_other_devices` for incident response.
5. Global revocation uses `vault_session_controls.revoke_all_after`; any device older than the marker is treated as revoked.

Example upsert call:

```sql
select *
from public.rpc_vault_upsert_blob(
  p_device_id := 'device-01',
  p_idempotency_key := '11111111-1111-1111-1111-111111111111',
  p_record_id := '22222222-2222-2222-2222-222222222222',
  p_expected_version := 3,
  p_ciphertext := 'base64-ciphertext',
  p_nonce := 'base64-nonce',
  p_gcm_tag := 'record-authentication-tag',
  p_key_version := 1,
  p_request_hash := 'sha256:...'
);
```

Example tombstone delete call:

```sql
select *
from public.rpc_vault_delete_blob(
  p_device_id := 'device-01',
  p_idempotency_key := '33333333-3333-3333-3333-333333333333',
  p_record_id := '22222222-2222-2222-2222-222222222222',
  p_expected_version := 4,
  p_request_hash := 'sha256:...'
);
```

## Apply migrations

1. Install Supabase CLI.
2. From repo root, login and link your project:

```bash
supabase login
supabase link --project-ref <your-project-ref>
```

3. Push migrations:

```bash
supabase db push
```

## Optional local validation (non-destructive)

```bash
supabase db lint
```

If Docker/local services are not configured, use static SQL review + CI checks and run `supabase db push` only in a configured environment.
