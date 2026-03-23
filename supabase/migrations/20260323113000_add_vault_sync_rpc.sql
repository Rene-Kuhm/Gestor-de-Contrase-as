-- Batch B2: CAS + idempotent RPC operations for vault sync.

create or replace function public.rpc_vault_upsert_blob(
  p_device_id text,
  p_idempotency_key uuid,
  p_record_id uuid,
  p_expected_version bigint,
  p_ciphertext text,
  p_nonce text,
  p_aad text,
  p_key_version integer,
  p_request_hash text default null
)
returns table (
  result_code text,
  applied boolean,
  idempotent_replay boolean,
  conflict boolean,
  message text,
  record_id uuid,
  current_version bigint,
  applied_version bigint,
  deleted_at timestamptz
)
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_existing_op public.vault_ops%rowtype;
  v_blob public.vault_blobs%rowtype;
  v_applied_version bigint;
  v_current_deleted_at timestamptz;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    return query
    select 'unauthenticated'::text, false, false, true, 'auth.uid() is null'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  if nullif(trim(coalesce(p_device_id, '')), '') is null then
    return query
    select 'invalid_device'::text, false, false, true, 'device_id is required'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  if nullif(trim(coalesce(p_ciphertext, '')), '') is null then
    return query
    select 'invalid_payload'::text, false, false, true, 'ciphertext is required'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  if nullif(trim(coalesce(p_nonce, '')), '') is null then
    return query
    select 'invalid_payload'::text, false, false, true, 'nonce is required'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  if p_key_version is null or p_key_version <= 0 then
    return query
    select 'invalid_payload'::text, false, false, true, 'key_version must be greater than zero'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  if not exists (
    select 1
    from public.vault_devices vd
    where vd.user_id = v_user_id
      and vd.device_id = p_device_id
  ) then
    return query
    select 'invalid_device'::text, false, false, true, 'device_id is not registered for current user'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  select *
  into v_existing_op
  from public.vault_ops vo
  where vo.user_id = v_user_id
    and vo.idempotency_key = p_idempotency_key
  for update;

  if found then
    if v_existing_op.op_type <> 'upsert_blob'
       or v_existing_op.device_id is distinct from p_device_id
       or v_existing_op.record_id is distinct from p_record_id
       or v_existing_op.expected_version is distinct from p_expected_version
       or v_existing_op.request_hash is distinct from p_request_hash then
      return query
      select 'idempotency_mismatch'::text, false, false, true, 'idempotency_key already used with different payload'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
      return;
    end if;

    select vb.version, vb.deleted_at
    into v_applied_version, v_current_deleted_at
    from public.vault_blobs vb
    where vb.user_id = v_user_id
      and vb.record_id = p_record_id;

    return query
    select
      'idempotent_replay'::text,
      true,
      true,
      false,
      'operation already applied'::text,
      p_record_id,
      v_applied_version,
      v_existing_op.applied_version,
      v_current_deleted_at;
    return;
  end if;

  insert into public.vault_ops (
    user_id,
    device_id,
    idempotency_key,
    op_type,
    record_id,
    expected_version,
    applied_version,
    request_hash
  )
  values (
    v_user_id,
    p_device_id,
    p_idempotency_key,
    'upsert_blob',
    p_record_id,
    p_expected_version,
    null,
    p_request_hash
  );

  select *
  into v_blob
  from public.vault_blobs vb
  where vb.user_id = v_user_id
    and vb.record_id = p_record_id
  for update;

  if not found then
    if p_expected_version is not null then
      delete from public.vault_ops vo
      where vo.user_id = v_user_id
        and vo.idempotency_key = p_idempotency_key;

      return query
      select 'cas_conflict'::text, false, false, true, 'record does not exist for expected_version'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
      return;
    end if;

    insert into public.vault_blobs (
      user_id,
      record_id,
      version,
      ciphertext,
      nonce,
      aad,
      key_version,
      deleted_at
    )
    values (
      v_user_id,
      p_record_id,
      1,
      p_ciphertext,
      p_nonce,
      p_aad,
      p_key_version,
      null
    )
    returning version, deleted_at
    into v_applied_version, v_blob.deleted_at;

    update public.vault_ops vo
    set applied_version = v_applied_version
    where vo.user_id = v_user_id
      and vo.idempotency_key = p_idempotency_key;

    return query
    select 'applied'::text, true, false, false, 'inserted new encrypted blob'::text, p_record_id, v_applied_version, v_applied_version, v_blob.deleted_at;
    return;
  end if;

  if p_expected_version is null or p_expected_version <> v_blob.version then
    delete from public.vault_ops vo
    where vo.user_id = v_user_id
      and vo.idempotency_key = p_idempotency_key;

    return query
    select 'cas_conflict'::text, false, false, true, 'expected_version does not match current version'::text, p_record_id, v_blob.version, null::bigint, v_blob.deleted_at;
    return;
  end if;

  v_applied_version := v_blob.version + 1;

  update public.vault_blobs vb
  set version = v_applied_version,
      ciphertext = p_ciphertext,
      nonce = p_nonce,
      aad = p_aad,
      key_version = p_key_version,
      deleted_at = null
  where vb.user_id = v_user_id
    and vb.record_id = p_record_id;

  update public.vault_ops vo
  set applied_version = v_applied_version
  where vo.user_id = v_user_id
    and vo.idempotency_key = p_idempotency_key;

  return query
  select 'applied'::text, true, false, false, 'updated encrypted blob'::text, p_record_id, v_applied_version, v_applied_version, null::timestamptz;
end;
$$;

create or replace function public.rpc_vault_delete_blob(
  p_device_id text,
  p_idempotency_key uuid,
  p_record_id uuid,
  p_expected_version bigint,
  p_request_hash text default null
)
returns table (
  result_code text,
  applied boolean,
  idempotent_replay boolean,
  conflict boolean,
  message text,
  record_id uuid,
  current_version bigint,
  applied_version bigint,
  deleted_at timestamptz
)
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_existing_op public.vault_ops%rowtype;
  v_blob public.vault_blobs%rowtype;
  v_applied_version bigint;
  v_deleted_at timestamptz;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    return query
    select 'unauthenticated'::text, false, false, true, 'auth.uid() is null'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  if nullif(trim(coalesce(p_device_id, '')), '') is null then
    return query
    select 'invalid_device'::text, false, false, true, 'device_id is required'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  if p_expected_version is null then
    return query
    select 'invalid_expected_version'::text, false, false, true, 'delete requires expected_version'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  if not exists (
    select 1
    from public.vault_devices vd
    where vd.user_id = v_user_id
      and vd.device_id = p_device_id
  ) then
    return query
    select 'invalid_device'::text, false, false, true, 'device_id is not registered for current user'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  select *
  into v_existing_op
  from public.vault_ops vo
  where vo.user_id = v_user_id
    and vo.idempotency_key = p_idempotency_key
  for update;

  if found then
    if v_existing_op.op_type <> 'delete_blob'
       or v_existing_op.device_id is distinct from p_device_id
       or v_existing_op.record_id is distinct from p_record_id
       or v_existing_op.expected_version is distinct from p_expected_version
       or v_existing_op.request_hash is distinct from p_request_hash then
      return query
      select 'idempotency_mismatch'::text, false, false, true, 'idempotency_key already used with different payload'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
      return;
    end if;

    select vb.version, vb.deleted_at
    into v_applied_version, v_deleted_at
    from public.vault_blobs vb
    where vb.user_id = v_user_id
      and vb.record_id = p_record_id;

    return query
    select
      'idempotent_replay'::text,
      true,
      true,
      false,
      'operation already applied'::text,
      p_record_id,
      v_applied_version,
      v_existing_op.applied_version,
      v_deleted_at;
    return;
  end if;

  insert into public.vault_ops (
    user_id,
    device_id,
    idempotency_key,
    op_type,
    record_id,
    expected_version,
    applied_version,
    request_hash
  )
  values (
    v_user_id,
    p_device_id,
    p_idempotency_key,
    'delete_blob',
    p_record_id,
    p_expected_version,
    null,
    p_request_hash
  );

  select *
  into v_blob
  from public.vault_blobs vb
  where vb.user_id = v_user_id
    and vb.record_id = p_record_id
  for update;

  if not found then
    delete from public.vault_ops vo
    where vo.user_id = v_user_id
      and vo.idempotency_key = p_idempotency_key;

    return query
    select 'cas_conflict'::text, false, false, true, 'record does not exist for expected_version'::text, p_record_id, null::bigint, null::bigint, null::timestamptz;
    return;
  end if;

  if p_expected_version <> v_blob.version then
    delete from public.vault_ops vo
    where vo.user_id = v_user_id
      and vo.idempotency_key = p_idempotency_key;

    return query
    select 'cas_conflict'::text, false, false, true, 'expected_version does not match current version'::text, p_record_id, v_blob.version, null::bigint, v_blob.deleted_at;
    return;
  end if;

  v_applied_version := v_blob.version + 1;
  v_deleted_at := now();

  update public.vault_blobs vb
  set version = v_applied_version,
      deleted_at = v_deleted_at
  where vb.user_id = v_user_id
    and vb.record_id = p_record_id;

  update public.vault_ops vo
  set applied_version = v_applied_version
  where vo.user_id = v_user_id
    and vo.idempotency_key = p_idempotency_key;

  return query
  select 'applied'::text, true, false, false, 'marked blob as tombstone'::text, p_record_id, v_applied_version, v_applied_version, v_deleted_at;
end;
$$;

grant execute on function public.rpc_vault_upsert_blob(
  text,
  uuid,
  uuid,
  bigint,
  text,
  text,
  text,
  integer,
  text
) to authenticated;

grant execute on function public.rpc_vault_delete_blob(
  text,
  uuid,
  uuid,
  bigint,
  text
) to authenticated;
