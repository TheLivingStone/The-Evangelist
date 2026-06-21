-- =====================================================================
-- The Evangelist — Church registration & vetting
-- Idempotent. Run AFTER schema.sql + policies.sql (safe to re-run).
--
-- Model: ANYONE can register/claim a church, but it is NOT trusted until an
-- owner verifies it (after a real meeting to confirm the pastor/church). So:
--   • register_church  → inserts a church, located at the caller's GPS point,
--                        claimed by the caller, is_verified=false,
--                        claim_status='pending'.
--   • claim_church     → a pastor claims an EXISTING directory church; records
--                        their claim and flips it back to pending for review.
-- Verification happens only in the admin dashboard.
-- =====================================================================

-- ---------- 1. Claim / vetting columns ----------
alter table churches add column if not exists claimant_name  text;
alter table churches add column if not exists claimant_role  text;   -- 'Lead Pastor', 'Elder', ...
alter table churches add column if not exists claimant_phone text;
alter table churches add column if not exists claimant_email text;
alter table churches add column if not exists claim_status   text not null default 'unclaimed';
alter table churches add column if not exists claim_notes    text;    -- internal notes from the vetting meeting
alter table churches add column if not exists claimed_at     timestamptz;

-- Constrain claim_status to known values (drop-then-add = re-runnable).
alter table churches drop constraint if exists churches_claim_status_chk;
alter table churches add constraint churches_claim_status_chk
  check (claim_status in ('unclaimed','pending','approved','rejected'));

create index if not exists idx_churches_claim_status on churches(claim_status);

-- ---------- 2. register_church RPC ----------
-- Creates a new directory entry located at the given GPS point, claimed by the
-- caller, pending review. Returns the new church id.
create or replace function register_church(
  p_name          text,
  p_lat           double precision,
  p_lng           double precision,
  p_address       text default null,
  p_city          text default null,
  p_service_times text default null,
  p_website       text default null,
  p_statement     text default null,
  p_claimant_name  text default null,
  p_claimant_role  text default null,
  p_claimant_phone text default null,
  p_claimant_email text default null
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid text := auth.jwt() ->> 'sub';
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
    claimant_name, claimant_role, claimant_phone, claimant_email, claimed_at
  ) values (
    p_name,
    case when p_lat is null or p_lng is null
         then null
         else st_point(p_lng, p_lat)::geography end,
    p_address, p_city, p_service_times, p_website, p_statement,
    v_uid, false, 'pending',
    p_claimant_name, p_claimant_role, p_claimant_phone, p_claimant_email, now()
  )
  returning id into v_id;

  return v_id;
end; $$;

-- ---------- 3. claim_church RPC ----------
-- A pastor claims an EXISTING church. Refuses if it is already verified AND
-- claimed by someone else (can't hijack a vetted listing). Otherwise records
-- the claim and sets it pending for owner review.
create or replace function claim_church(
  p_church_id      uuid,
  p_claimant_name  text,
  p_claimant_role  text,
  p_claimant_phone text default null,
  p_claimant_email text default null,
  p_message        text default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid text := auth.jwt() ->> 'sub';
  v_existing_owner text;
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
    claimed_by     = v_uid,
    claimant_name  = p_claimant_name,
    claimant_role  = p_claimant_role,
    claimant_phone = p_claimant_phone,
    claimant_email = p_claimant_email,
    claim_notes    = p_message,
    claim_status   = 'pending',
    claimed_at     = now()
  where id = p_church_id;
end; $$;

-- ---------- 4. nearby_churches: include verification status ----------
-- Return type changes, so drop the old function first.
drop function if exists nearby_churches(double precision, double precision, int);
create or replace function nearby_churches(
  lat double precision, lng double precision, radius_m int default 8000
)
returns table (
  id uuid, name text, city text, address text, service_times text,
  website text, is_verified boolean, claim_status text,
  distance_m double precision, lat_out double precision, lng_out double precision
)
language sql security definer set search_path = public stable as $$
  select c.id, c.name, c.city, c.address, c.service_times,
         c.website, c.is_verified, c.claim_status,
         st_distance(c.location, st_point(lng, lat)::geography) as distance_m,
         st_y(c.location::geometry) as lat_out,
         st_x(c.location::geometry) as lng_out
  from churches c
  where c.location is not null
    and st_dwithin(c.location, st_point(lng, lat)::geography, radius_m)
  order by distance_m
  limit 50;
$$;

grant execute on function register_church(text,double precision,double precision,text,text,text,text,text,text,text,text,text) to authenticated;
grant execute on function claim_church(uuid,text,text,text,text,text) to authenticated;
grant execute on function nearby_churches(double precision,double precision,int) to authenticated;
