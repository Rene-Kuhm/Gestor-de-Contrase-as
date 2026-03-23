# Supabase migrations (B1 + B2)

This project now includes an initial Supabase schema for zero-knowledge sync.

## Files

- `supabase/migrations/20260323100000_initial_vault_schema.sql`
- `supabase/migrations/20260323113000_add_vault_sync_rpc.sql`

## What these migrations create

- Tables: `vault_devices`, `vault_blobs`, `vault_ops`
- Indexes for owner + sync query patterns
- `updated_at` trigger helper (`public.set_updated_at`)
- RLS enabled and forced on all three tables
- Owner-only RLS policies (`auth.uid() = user_id`) for select/insert/update/delete
- RPC functions for sync writes with CAS + idempotency:
  - `public.rpc_vault_upsert_blob(...)`
  - `public.rpc_vault_delete_blob(...)`

## RPC behavior (Batch B2)

- Both RPCs run inside a single SQL transaction.
- Both require authenticated context (`auth.uid()`) and registered `device_id`.
- Idempotency is keyed by `(auth.uid(), idempotency_key)` via `vault_ops`.
- If `idempotency_key` is reused with a different payload, result is `idempotency_mismatch`.
- If `expected_version` does not match current row version, result is `cas_conflict`.
- Every effective mutation writes an entry in `vault_ops` with `applied_version`.

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
  p_aad := 'record-metadata',
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
