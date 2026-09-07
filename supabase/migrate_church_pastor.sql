-- =====================================================================
-- Go and Tell — Lead pastor contact for church verification
-- Idempotent. Run AFTER migrate_church_registration.sql (safe to re-run).
--
-- A church is only marked verified after the team has spoken to the person
-- who leads it. So every registration / claim now records the LEAD PASTOR's
-- name, phone and email (separate from whoever submitted the form), plus the
-- best time to reach them, so the team can call, email, and book a short
-- visit to confirm the church is taking part.
-- =====================================================================

-- ---------- 1. Pastor columns ----------
alter table churches add column if not exists pastor_name       text;
alter table churches add column if not exists pastor_phone      text;
alter table churches add column if not exists pastor_email      text;
alter table churches add column if not exists best_time_to_meet text;

-- ---------- 2. Drop every older version of the two functions ----------
-- Adding defaulted parameters would leave two overloads that PostgREST cannot
-- tell apart, so every existing signature (whatever version this database
-- is on) is dropped before the new ones are created.
do $$
declare fn text;
begin
  for fn in
    select p.oid::regprocedure::text
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('register_church', 'claim_church')
  loop
    execute format('drop function if exists %s', fn);
  end loop;
end $$;

-- ---------- 3. register_church: accept pastor details ----------
create or replace function register_church(
  p_name              text,
  p_lat               double precision,
  p_lng               double precision,
  p_address           text default null,
  p_city              text default null,
  p_service_times     text default null,
  p_website           text default null,
  p_statement         text default null,
  p_claimant_name     text default null,
  p_claimant_role     text default null,
  p_claimant_phone    text default null,
  p_claimant_email    text default null,
  p_pastor_name       text default null,
  p_pastor_phone      text default null,
  p_pastor_email      text default null,
  p_best_time_to_meet text default null
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Church name is required';
  end if;

  insert into churches (
    name, location, address, city, service_times, website, statement_of_faith,
    claimed_by, is_verified, claim_status,
    claimant_name, claimant_role, claimant_phone, claimant_email, claimed_at,
    pastor_name, pastor_phone, pastor_email, best_time_to_meet
  ) values (
    p_name,
    case when p_lat is null or p_lng is null
         then null
         else st_point(p_lng, p_lat)::geography end,
    p_address, p_city, p_service_times, p_website, p_statement,
    v_uid, false, 'pending',
    p_claimant_name, p_claimant_role, p_claimant_phone, p_claimant_email, now(),
    p_pastor_name, p_pastor_phone, p_pastor_email, p_best_time_to_meet
  )
  returning id into v_id;

  return v_id;
end; $$;

-- ---------- 4. claim_church: accept pastor details ----------
create or replace function claim_church(
  p_church_id         uuid,
  p_claimant_name     text,
  p_claimant_role     text,
  p_claimant_phone    text default null,
  p_claimant_email    text default null,
  p_message           text default null,
  p_pastor_name       text default null,
  p_pastor_phone      text default null,
  p_pastor_email      text default null,
  p_best_time_to_meet text default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_existing_owner uuid;
  v_verified boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select claimed_by, is_verified into v_existing_owner, v_verified
  from churches where id = p_church_id;

  if not found then
    raise exception 'Church not found';
  end if;
  if v_verified and v_existing_owner is not null and v_existing_owner <> v_uid then
    raise exception 'This church is already verified and managed by someone else';
  end if;

  update churches set
    claimed_by        = v_uid,
    claimant_name     = p_claimant_name,
    claimant_role     = p_claimant_role,
    claimant_phone    = p_claimant_phone,
    claimant_email    = p_claimant_email,
    claim_notes       = p_message,
    -- Keep any pastor details already on file when the claim omits them.
    pastor_name       = coalesce(p_pastor_name, pastor_name),
    pastor_phone      = coalesce(p_pastor_phone, pastor_phone),
    pastor_email      = coalesce(p_pastor_email, pastor_email),
    best_time_to_meet = coalesce(p_best_time_to_meet, best_time_to_meet),
    claim_status      = 'pending',
    claimed_at        = now()
  where id = p_church_id;
end; $$;

grant execute on function register_church(
  text, double precision, double precision,
  text, text, text, text, text, text, text, text, text, text, text, text, text
) to authenticated;
grant execute on function claim_church(
  uuid, text, text, text, text, text, text, text, text, text
) to authenticated;

-- Ask PostgREST (the API the app talks to) to pick up the new signatures now.
notify pgrst, 'reload schema';
