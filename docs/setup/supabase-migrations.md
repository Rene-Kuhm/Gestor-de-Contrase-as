# Supabase migrations (Batch B1)

This project now includes an initial Supabase schema for zero-knowledge sync.

## Files

- `supabase/migrations/20260323100000_initial_vault_schema.sql`

## What this migration creates

- Tables: `vault_devices`, `vault_blobs`, `vault_ops`
- Indexes for owner + sync query patterns
- `updated_at` trigger helper (`public.set_updated_at`)
- RLS enabled and forced on all three tables
- Owner-only RLS policies (`auth.uid() = user_id`) for select/insert/update/delete

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
