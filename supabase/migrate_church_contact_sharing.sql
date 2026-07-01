-- =====================================================================
-- The Evangelist — Church contact sharing (consent-gated)
-- Built 2026-07-01. Idempotent (safe to re-run). Run AFTER schema.sql +
-- policies.sql + migrate_church_members.sql.
--
-- AUTH MODEL: Supabase Auth. User ids are uuid; the current user is
-- auth.uid().
--
-- WHY: a member's contacts ("My People") are private by default. This lets
-- a CONFIRMED church member opt individual contacts into being visible to
-- their church's claimant, so the church can follow up. Off by default —
-- nothing changes for anyone until a member explicitly shares a contact.
--
-- MODEL:
--   • profiles.share_contacts_with_church — a member's default for NEW
--     contacts (the app reads this to pre-fill the per-contact switch; the
--     column itself still defaults to false).
--   • contacts.visible_to_church — per-contact opt-in flag. Only takes
--     effect while the contact's owner has a CONFIRMED church_members row
--     at the church in question — leaving, being removed, or switching
--     churches (join_church/leave_church/remove_member all flip status
--     away from 'confirmed') automatically stops it applying, no cleanup
--     needed here.
--   • A church claimant can SELECT shared contacts via a new RLS policy,
--     and read them (with the owner's name) via church_shared_contacts().
-- =====================================================================

-- ---------- 1. columns ----------
alter table profiles add column if not exists share_contacts_with_church boolean not null default false;
alter table contacts add column if not exists visible_to_church boolean not null default false;

-- ---------- 2. RLS: claimant can read contacts shared with their church ----------
-- Additive alongside the existing owner-only policies in policies.sql — the
-- owner keeps full read/write access; this just adds a second, narrower way
-- in for a church claimant.
drop policy if exists "claimant reads shared contacts" on contacts;
create policy "claimant reads shared contacts" on contacts
  for select to authenticated
  using (
    visible_to_church
    and exists (
      select 1
      from church_members cm
      join churches c on c.id = cm.church_id
      where cm.member_id = contacts.owner_id
        and cm.status = 'confirmed'
        and c.claimed_by = auth.uid()
    )
  );

-- ---------- 3. church_shared_contacts: contacts shared with a church I manage ----------
create or replace function church_shared_contacts(p_church_id uuid)
returns table (
  contact_id uuid,
  owner_id uuid,
  owner_name text,
  first_name text,
  last_name text,
  phone text,
  email text,
  city text,
  met_location text,
  date_met date,
  status text,
  notes text,
  next_followup_at date,
  added_at timestamptz
)
language sql security definer set search_path = public stable as $$
  select ct.id, ct.owner_id, p.full_name,
         ct.first_name, ct.last_name, ct.phone, ct.email,
         ct.city, ct.met_location, ct.date_met, ct.status::text,
         ct.notes, ct.next_followup_at, ct.created_at
  from contacts ct
  join profiles p on p.id = ct.owner_id
  join church_members cm on cm.member_id = ct.owner_id
    and cm.status = 'confirmed'
    and cm.church_id = p_church_id
  join churches c on c.id = cm.church_id
  where ct.visible_to_church = true
    and c.claimed_by = auth.uid()
  order by ct.created_at desc;
$$;

grant execute on function church_shared_contacts(uuid) to authenticated;
