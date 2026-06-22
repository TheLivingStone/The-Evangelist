-- =====================================================================
-- The Evangelist — Church membership (members ↔ churches)
-- Built 2026-06-20, corrected for Supabase Auth 2026-06-21. Idempotent
-- (safe to re-run). Run AFTER schema.sql + policies.sql +
-- migrate_church_registration.sql.
--
-- AUTH MODEL: Supabase Auth. User ids are uuid; the current user is auth.uid()
-- (NOT auth.jwt()->>'sub'). Every column referencing profiles(id) is uuid.
--
-- WHY: link evangelists to a REAL directory church (not the free-text
-- profiles.church). Once linked, every salvation/conversation/prayer a member
-- logs rolls up to their church → a "church fruitfulness" signal: churches whose
-- people actively evangelize and see salvations are healthy, fruitful churches.
--
-- MODEL:
--   • A member picks their church from the directory  → join_church()
--       creates a PENDING membership.
--   • The church's claimant confirms or removes them  → confirm_member()/remove_member()
--   • ONE home church per member (unique on member_id where status<>'removed').
-- =====================================================================

-- ---------- 1. church_members table ----------
-- Drop any stale/partial version first: an earlier run created this table with
-- member_id typed as text, which is incompatible with profiles.id (uuid). No
-- real data exists yet, so dropping is safe and makes this self-healing.
drop table if exists church_members cascade;
create table church_members (
  id          uuid primary key default gen_random_uuid(),
  church_id   uuid not null references churches(id) on delete cascade,
  member_id   uuid not null references profiles(id) on delete cascade,
  status      text not null default 'pending',   -- pending | confirmed | removed
  role        text,                              -- optional: 'member','leader','volunteer'
  requested_at timestamptz not null default now(),
  confirmed_at timestamptz,
  confirmed_by uuid references profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

alter table church_members drop constraint if exists church_members_status_chk;
alter table church_members add constraint church_members_status_chk
  check (status in ('pending','confirmed','removed'));

-- One active (non-removed) home church per member.
create unique index if not exists uq_church_members_one_home
  on church_members (member_id) where status <> 'removed';

create index if not exists idx_church_members_church on church_members (church_id, status);
create index if not exists idx_church_members_member on church_members (member_id);

-- Convenience FK on profiles so we can read a member's confirmed church directly.
alter table profiles add column if not exists church_id uuid references churches(id) on delete set null;
create index if not exists idx_profiles_church_id on profiles (church_id);

-- ---------- 2. RLS ----------
alter table church_members enable row level security;

-- A member can see their own membership rows.
drop policy if exists cm_member_read on church_members;
create policy cm_member_read on church_members
  for select to authenticated
  using (member_id = auth.uid());

-- A church claimant can see the membership rows for churches they manage.
drop policy if exists cm_claimant_read on church_members;
create policy cm_claimant_read on church_members
  for select to authenticated
  using (exists (
    select 1 from churches c
    where c.id = church_members.church_id
      and c.claimed_by = auth.uid()
  ));

-- All writes go through the SECURITY DEFINER RPCs below (no direct client write).

-- ---------- 3. join_church: member attaches to a directory church ----------
create or replace function join_church(p_church_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (select 1 from churches where id = p_church_id) then
    raise exception 'Church not found';
  end if;

  -- Drop any existing non-removed membership (one home church).
  update church_members
     set status = 'removed'
   where member_id = v_uid and status <> 'removed' and church_id <> p_church_id;

  -- Re-activate an existing row for this church, else insert a fresh one.
  update church_members
     set status = 'pending', requested_at = now(), confirmed_at = null, confirmed_by = null
   where member_id = v_uid and church_id = p_church_id
   returning id into v_id;

  if v_id is null then
    insert into church_members (church_id, member_id, status)
    values (p_church_id, v_uid, 'pending')
    returning id into v_id;
  end if;

  return v_id;
end; $$;

-- ---------- 4. leave_church: member detaches ----------
create or replace function leave_church()
returns void
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  update church_members set status = 'removed'
    where member_id = v_uid and status <> 'removed';
  update profiles set church_id = null where id = v_uid;
end; $$;

-- ---------- 5. confirm_member: church claimant approves a pending member ----
create or replace function confirm_member(p_membership_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_church uuid;
  v_member uuid;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select cm.church_id, cm.member_id into v_church, v_member
  from church_members cm where cm.id = p_membership_id;
  if not found then raise exception 'Membership not found'; end if;

  if not exists (
    select 1 from churches c where c.id = v_church and c.claimed_by = v_uid
  ) then
    raise exception 'Only the church manager can confirm members';
  end if;

  update church_members
     set status = 'confirmed', confirmed_at = now(), confirmed_by = v_uid
   where id = p_membership_id;

  update profiles set church_id = v_church where id = v_member;
end; $$;

-- ---------- 6. remove_member: church claimant removes a member ------------
create or replace function remove_member(p_membership_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_church uuid;
  v_member uuid;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select cm.church_id, cm.member_id into v_church, v_member
  from church_members cm where cm.id = p_membership_id;
  if not found then raise exception 'Membership not found'; end if;

  if not exists (
    select 1 from churches c where c.id = v_church and c.claimed_by = v_uid
  ) then
    raise exception 'Only the church manager can remove members';
  end if;

  update church_members set status = 'removed' where id = p_membership_id;
  update profiles set church_id = null
    where id = v_member and church_id = v_church;
end; $$;

-- ---------- 7. my_church_membership: what church am I in? ----------
create or replace function my_church_membership()
returns table (
  membership_id uuid, church_id uuid, church_name text, city text,
  is_verified boolean, status text, requested_at timestamptz, confirmed_at timestamptz
)
language sql security definer set search_path = public stable as $$
  select cm.id, c.id, c.name, c.city, c.is_verified,
         cm.status, cm.requested_at, cm.confirmed_at
  from church_members cm
  join churches c on c.id = cm.church_id
  where cm.member_id = auth.uid() and cm.status <> 'removed'
  order by cm.requested_at desc
  limit 1;
$$;

-- ---------- 8. church_member_requests: pending members for MY church ----------
create or replace function church_member_requests(p_church_id uuid)
returns table (
  membership_id uuid, member_id uuid, full_name text, username text,
  city text, avatar_url text, status text, requested_at timestamptz,
  total_salvations int, total_conversations int
)
language sql security definer set search_path = public stable as $$
  select cm.id, p.id, p.full_name, p.username, p.city, p.avatar_url,
         cm.status, cm.requested_at, p.total_salvations, p.total_conversations
  from church_members cm
  join profiles p on p.id = cm.member_id
  join churches c on c.id = cm.church_id
  where cm.church_id = p_church_id
    and c.claimed_by = auth.uid()   -- only the manager sees this
    and cm.status <> 'removed'
  order by (cm.status = 'pending') desc, cm.requested_at desc;
$$;

grant execute on function join_church(uuid) to authenticated;
grant execute on function leave_church() to authenticated;
grant execute on function confirm_member(uuid) to authenticated;
grant execute on function remove_member(uuid) to authenticated;
grant execute on function my_church_membership() to authenticated;
grant execute on function church_member_requests(uuid) to authenticated;

-- =====================================================================
-- 9. ADMIN: Church fruitfulness (service-role only) — the whole point.
--    Ranks churches by the evangelism their members actually do.
-- =====================================================================

create or replace function admin_church_fruitfulness(p_days int default null, p_limit int default 100)
returns table (
  church_id uuid,
  name text,
  city text,
  is_verified boolean,
  members int,
  active_members int,
  salvations int,
  conversations int,
  prayers int,
  followups int,
  fruitfulness numeric
)
language sql security definer set search_path = public stable as $$
  with mem as (
    select cm.church_id, cm.member_id
    from church_members cm
    where cm.status = 'confirmed'
  ),
  acts as (
    select m.church_id, a.type, a.user_id, a.occurred_at
    from mem m
    join activity_logs a on a.user_id = m.member_id
    where p_days is null or a.occurred_at >= (current_date - (p_days - 1))
  ),
  agg as (
    select
      m.church_id,
      count(distinct m.member_id)::int as members,
      count(distinct a.user_id) filter (where a.user_id is not null)::int as active_members,
      count(a.*) filter (where a.type = 'salvation')::int as salvations,
      count(a.*) filter (where a.type = 'conversation')::int as conversations,
      count(a.*) filter (where a.type = 'prayer')::int as prayers,
      count(a.*) filter (where a.type = 'followup')::int as followups
    from mem m
    left join acts a on a.church_id = m.church_id and a.user_id = m.member_id
    group by m.church_id
  )
  select
    c.id, c.name, c.city, c.is_verified,
    coalesce(g.members,0), coalesce(g.active_members,0),
    coalesce(g.salvations,0), coalesce(g.conversations,0),
    coalesce(g.prayers,0), coalesce(g.followups,0),
    (coalesce(g.salvations,0) * 5
     + coalesce(g.conversations,0) * 2
     + coalesce(g.prayers,0)
     + coalesce(g.followups,0))::numeric as fruitfulness
  from churches c
  join agg g on g.church_id = c.id
  order by fruitfulness desc, coalesce(g.salvations,0) desc
  limit p_limit;
$$;

create or replace function admin_church_members(p_church_id uuid)
returns table (
  membership_id uuid, member_id uuid, full_name text, username text,
  city text, status text, requested_at timestamptz, confirmed_at timestamptz,
  total_salvations int, total_conversations int, current_streak int
)
language sql security definer set search_path = public stable as $$
  select cm.id, p.id, p.full_name, p.username, p.city,
         cm.status, cm.requested_at, cm.confirmed_at,
         p.total_salvations, p.total_conversations, p.current_streak
  from church_members cm
  join profiles p on p.id = cm.member_id
  where cm.church_id = p_church_id and cm.status <> 'removed'
  order by (cm.status = 'pending') desc, p.total_salvations desc;
$$;

create or replace function admin_membership_stats()
returns table (
  churches_with_members int,
  confirmed_members int,
  pending_members int,
  members_evangelizing int
)
language sql security definer set search_path = public stable as $$
  select
    (select count(distinct church_id) from church_members where status = 'confirmed')::int,
    (select count(*) from church_members where status = 'confirmed')::int,
    (select count(*) from church_members where status = 'pending')::int,
    (select count(distinct cm.member_id)
       from church_members cm
       join activity_logs a on a.user_id = cm.member_id
      where cm.status = 'confirmed')::int;
$$;

-- Admin grants: these admin_* functions are service-role only.
do $$
declare fn text;
begin
  for fn in
    select format('%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('admin_church_fruitfulness','admin_church_members','admin_membership_stats')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', fn);
    execute format('grant execute on function %s to service_role', fn);
  end loop;
end $$;
