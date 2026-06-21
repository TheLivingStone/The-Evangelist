-- =====================================================================
-- The Evangelist — Feed upgrade: comment counts + post photos
-- Idempotent. Run AFTER schema.sql + policies.sql (safe to re-run).
-- Adds:
--   1. post_comment_counts  — view powering the "💬 N" indicator on cards
--   2. a public 'post-photos' Storage bucket + RLS so users can attach a
--      photo to a post (public read; owner-scoped writes).
-- The comments TABLE and its RLS already exist (schema.sql / policies.sql);
-- this file only adds the count view and the photo storage plumbing.
-- =====================================================================

-- ---------- 1. Comment counts per post (mirrors post_reaction_counts) ----------
create or replace view post_comment_counts as
  select post_id, count(*)::int as cnt
  from comments
  group by post_id;

-- ---------- 2. Public Storage bucket for post photos ----------
-- Create the bucket if missing. Public so image URLs load like normal CDN
-- links (posts are already public). 5 MB cap, common image mime types only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'post-photos',
  'post-photos',
  true,
  5242880,                                  -- 5 MB
  array['image/jpeg','image/png','image/webp','image/heic']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- RLS on storage.objects: public read for this bucket, owner-scoped writes.
-- Files are stored under "<clerk_user_id>/<filename>", so the first path
-- segment must equal the caller's Clerk sub for insert/update/delete.
-- Drop-then-create keeps this migration safely re-runnable.
drop policy if exists "post-photos public read"   on storage.objects;
drop policy if exists "post-photos owner upload"   on storage.objects;
drop policy if exists "post-photos owner update"   on storage.objects;
drop policy if exists "post-photos owner delete"   on storage.objects;

create policy "post-photos public read"
  on storage.objects for select
  using (bucket_id = 'post-photos');

create policy "post-photos owner upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = (auth.jwt()->>'sub')
  );

create policy "post-photos owner update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = (auth.jwt()->>'sub')
  );

create policy "post-photos owner delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = (auth.jwt()->>'sub')
  );
