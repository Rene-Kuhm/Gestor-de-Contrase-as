-- Batch B3: device registration + heartbeat RPCs.

alter table public.vault_devices
  add column if not exists platform text,
  add column if not exists app_version text;

create or replace function public.rpc_vault_register_device(
  p_device_id text,
  p_device_name text default null,
  p_platform text default null,
  p_app_version text default null,
  p_last_seen_at timestamptz default null
)
returns table (
  result_code text,
  device_id text,
  registered boolean,
  message text,
  last_seen_at timestamptz
)
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_device_id text;
  v_last_seen timestamptz;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    return query
    select
      'unauthenticated'::text,
      null::text,
      false,
      'auth.uid() is null'::text,
      null::timestamptz;
    return;
  end if;

  v_device_id := nullif(trim(coalesce(p_device_id, '')), '');
  if v_device_id is null then
    return query
    select
      'invalid_device'::text,
      null::text,
      false,
      'device_id is required'::text,
      null::timestamptz;
    return;
  end if;

  v_last_seen := coalesce(p_last_seen_at, now());

  insert into public.vault_devices (
    user_id,
    device_id,
    device_name,
    platform,
    app_version,
    last_seen_at
  )
  values (
    v_user_id,
    v_device_id,
    nullif(trim(coalesce(p_device_name, '')), ''),
    nullif(trim(coalesce(p_platform, '')), ''),
    nullif(trim(coalesce(p_app_version, '')), ''),
    v_last_seen
  )
  on conflict (user_id, device_id)
  do update
  set device_name = coalesce(excluded.device_name, public.vault_devices.device_name),
      platform = coalesce(excluded.platform, public.vault_devices.platform),
      app_version = coalesce(excluded.app_version, public.vault_devices.app_version),
      last_seen_at = greatest(
        coalesce(public.vault_devices.last_seen_at, '-infinity'::timestamptz),
        excluded.last_seen_at
      );

  return query
  select
    'registered'::text,
    v_device_id,
    true,
    'device registered or refreshed'::text,
    v_last_seen;
end;
$$;

create or replace function public.rpc_vault_device_heartbeat(
  p_device_id text,
  p_device_name text default null,
  p_platform text default null,
  p_app_version text default null,
  p_last_seen_at timestamptz default null
)
returns table (
  result_code text,
  device_id text,
  heartbeat_updated boolean,
  message text,
  last_seen_at timestamptz
)
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_device_id text;
  v_last_seen timestamptz;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    return query
    select
      'unauthenticated'::text,
      null::text,
      false,
      'auth.uid() is null'::text,
      null::timestamptz;
    return;
  end if;

  v_device_id := nullif(trim(coalesce(p_device_id, '')), '');
  if v_device_id is null then
    return query
    select
      'invalid_device'::text,
      null::text,
      false,
      'device_id is required'::text,
      null::timestamptz;
    return;
  end if;

  v_last_seen := coalesce(p_last_seen_at, now());

  insert into public.vault_devices (
    user_id,
    device_id,
    device_name,
    platform,
    app_version,
    last_seen_at
  )
  values (
    v_user_id,
    v_device_id,
    nullif(trim(coalesce(p_device_name, '')), ''),
    nullif(trim(coalesce(p_platform, '')), ''),
    nullif(trim(coalesce(p_app_version, '')), ''),
    v_last_seen
  )
  on conflict (user_id, device_id)
  do update
  set device_name = coalesce(excluded.device_name, public.vault_devices.device_name),
      platform = coalesce(excluded.platform, public.vault_devices.platform),
      app_version = coalesce(excluded.app_version, public.vault_devices.app_version),
      last_seen_at = greatest(
        coalesce(public.vault_devices.last_seen_at, '-infinity'::timestamptz),
        excluded.last_seen_at
      );

  return query
  select
    'heartbeat_ok'::text,
    v_device_id,
    true,
    'device heartbeat stored'::text,
    v_last_seen;
end;
$$;

grant execute on function public.rpc_vault_register_device(
  text,
  text,
  text,
  text,
  timestamptz
) to authenticated;

grant execute on function public.rpc_vault_device_heartbeat(
  text,
  text,
  text,
  text,
  timestamptz
) to authenticated;
