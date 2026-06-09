-- Initial schema for zero-knowledge vault sync.
-- Batch B1: Supabase schema + owner-only RLS policies.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.vault_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  device_id text not null,
  device_name text,
  device_public_key text,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vault_devices_user_device_unique unique (user_id, device_id),
  constraint vault_devices_device_id_not_empty check (char_length(trim(device_id)) > 0)
);

create table if not exists public.vault_blobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  record_id uuid not null,
  version bigint not null default 1,
  ciphertext text not null,
  nonce text not null,
  gcm_tag text,
  aad text, -- Legacy transport name kept only for existing beta data.
  key_version integer not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vault_blobs_user_record_unique unique (user_id, record_id),
  constraint vault_blobs_version_positive check (version > 0),
  constraint vault_blobs_key_version_positive check (key_version > 0),
  constraint vault_blobs_ciphertext_not_empty check (char_length(trim(ciphertext)) > 0),
  constraint vault_blobs_nonce_not_empty check (char_length(trim(nonce)) > 0)
);

create table if not exists public.vault_ops (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  device_id text not null,
  idempotency_key uuid not null,
  op_type text not null,
  record_id uuid not null,
  expected_version bigint,
  applied_version bigint,
  request_hash text,
  created_at timestamptz not null default now(),
  constraint vault_ops_user_idempotency_unique unique (user_id, idempotency_key),
  constraint vault_ops_device_fk foreign key (user_id, device_id)
    references public.vault_devices (user_id, device_id) on delete cascade,
  constraint vault_ops_op_type_valid check (op_type in ('upsert_blob', 'delete_blob')),
  constraint vault_ops_expected_version_positive check (expected_version is null or expected_version > 0),
  constraint vault_ops_applied_version_positive check (applied_version is null or applied_version > 0),
  constraint vault_ops_request_hash_not_empty check (request_hash is null or char_length(trim(request_hash)) > 0)
);

create table if not exists public.vault_session_controls (
  user_id uuid primary key references auth.users (id) on delete cascade,
  revoke_all_after timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_vault_devices_user_last_seen
  on public.vault_devices (user_id, last_seen_at desc);

create index if not exists idx_vault_blobs_user_updated_at
  on public.vault_blobs (user_id, updated_at desc);

create index if not exists idx_vault_blobs_user_deleted_at
  on public.vault_blobs (user_id, deleted_at)
  where deleted_at is not null;

create index if not exists idx_vault_ops_user_created_at
  on public.vault_ops (user_id, created_at desc);

create index if not exists idx_vault_ops_user_record_created_at
  on public.vault_ops (user_id, record_id, created_at desc);

drop trigger if exists trg_vault_devices_set_updated_at on public.vault_devices;
create trigger trg_vault_devices_set_updated_at
before update on public.vault_devices
for each row
execute function public.set_updated_at();

drop trigger if exists trg_vault_blobs_set_updated_at on public.vault_blobs;
create trigger trg_vault_blobs_set_updated_at
before update on public.vault_blobs
for each row
execute function public.set_updated_at();

drop trigger if exists trg_vault_session_controls_set_updated_at on public.vault_session_controls;
create trigger trg_vault_session_controls_set_updated_at
before update on public.vault_session_controls
for each row
execute function public.set_updated_at();

alter table public.vault_devices enable row level security;
alter table public.vault_devices force row level security;

alter table public.vault_blobs enable row level security;
alter table public.vault_blobs force row level security;

alter table public.vault_ops enable row level security;
alter table public.vault_ops force row level security;

alter table public.vault_session_controls enable row level security;
alter table public.vault_session_controls force row level security;

drop policy if exists vault_devices_select_owner on public.vault_devices;
create policy vault_devices_select_owner
on public.vault_devices
for select
using (auth.uid() = user_id);

drop policy if exists vault_devices_insert_owner on public.vault_devices;
create policy vault_devices_insert_owner
on public.vault_devices
for insert
with check (auth.uid() = user_id);

drop policy if exists vault_devices_update_owner on public.vault_devices;
create policy vault_devices_update_owner
on public.vault_devices
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists vault_devices_delete_owner on public.vault_devices;
create policy vault_devices_delete_owner
on public.vault_devices
for delete
using (auth.uid() = user_id);

drop policy if exists vault_blobs_select_owner on public.vault_blobs;
create policy vault_blobs_select_owner
on public.vault_blobs
for select
using (auth.uid() = user_id);

drop policy if exists vault_blobs_insert_owner on public.vault_blobs;
create policy vault_blobs_insert_owner
on public.vault_blobs
for insert
with check (auth.uid() = user_id);

drop policy if exists vault_blobs_update_owner on public.vault_blobs;
create policy vault_blobs_update_owner
on public.vault_blobs
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists vault_blobs_delete_owner on public.vault_blobs;
create policy vault_blobs_delete_owner
on public.vault_blobs
for delete
using (auth.uid() = user_id);

drop policy if exists vault_ops_select_owner on public.vault_ops;
create policy vault_ops_select_owner
on public.vault_ops
for select
using (auth.uid() = user_id);

drop policy if exists vault_ops_insert_owner on public.vault_ops;
create policy vault_ops_insert_owner
on public.vault_ops
for insert
with check (auth.uid() = user_id);

drop policy if exists vault_ops_update_owner on public.vault_ops;
create policy vault_ops_update_owner
on public.vault_ops
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists vault_ops_delete_owner on public.vault_ops;
create policy vault_ops_delete_owner
on public.vault_ops
for delete
using (auth.uid() = user_id);

drop policy if exists vault_session_controls_select_owner on public.vault_session_controls;
create policy vault_session_controls_select_owner
on public.vault_session_controls
for select
using (auth.uid() = user_id);

drop policy if exists vault_session_controls_insert_owner on public.vault_session_controls;
create policy vault_session_controls_insert_owner
on public.vault_session_controls
for insert
with check (auth.uid() = user_id);

drop policy if exists vault_session_controls_update_owner on public.vault_session_controls;
create policy vault_session_controls_update_owner
on public.vault_session_controls
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists vault_session_controls_delete_owner on public.vault_session_controls;
create policy vault_session_controls_delete_owner
on public.vault_session_controls
for delete
using (auth.uid() = user_id);
