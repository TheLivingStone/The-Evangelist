-- Moderation: content reporting + user blocking (App Store Guideline 1.2)
-- Adds the two mechanisms Apple requires for user-generated content:
--   1. report objectionable posts/comments
--   2. block abusive users (their content disappears for the blocker)
-- Safe to re-run.

-- ---------- REPORTS ----------
do $$ begin
  create type report_status as enum ('pending','reviewed','actioned','dismissed');
exception when duplicate_object then null; end $$;

create table if not exists content_reports (
  id            uuid primary key default gen_random_uuid(),
  reporter_id   uuid not null references profiles(id) on delete cascade,
  post_id       uuid references posts(id)    on delete cascade,
  comment_id    uuid references comments(id) on delete cascade,
  reason        text not null,
  details       text,
  status        report_status not null default 'pending',
  created_at    timestamptz not null default now(),
  -- exactly one target
  constraint content_reports_one_target check (
    (post_id is not null and comment_id is null) or
    (post_id is null and comment_id is not null)
  )
);

-- One report per user per item (re-reporting updates the existing row).
create unique index if not exists uq_report_post
  on content_reports(reporter_id, post_id) where post_id is not null;
create unique index if not exists uq_report_comment
  on content_reports(reporter_id, comment_id) where comment_id is not null;
create index if not exists idx_reports_status on content_reports(status, created_at desc);

alter table content_reports enable row level security;

drop policy if exists "reporter creates report" on content_reports;
create policy "reporter creates report" on content_reports
  for insert to authenticated with check (reporter_id = auth.uid());

drop policy if exists "reporter reads own reports" on content_reports;
create policy "reporter reads own reports" on content_reports
  for select to authenticated using (reporter_id = auth.uid());

-- ---------- BLOCKS ----------
create table if not exists user_blocks (
  blocker_id  uuid not null references profiles(id) on delete cascade,
  blocked_id  uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id <> blocked_id)
);
create index if not exists idx_blocks_blocker on user_blocks(blocker_id);

alter table user_blocks enable row level security;

drop policy if exists "own blocks" on user_blocks;
create policy "own blocks" on user_blocks
  for all to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- ---------- HIDE BLOCKED CONTENT ----------
-- Blocking is enforced in the database, not just the UI: a blocked author's
-- posts and comments stop being selectable by the blocker outright.
drop policy if exists "public posts readable" on posts;
create policy "public posts readable" on posts for select to authenticated
using (
  (is_public = true or author_id = auth.uid())
  and not exists (
    select 1 from user_blocks b
    where b.blocker_id = auth.uid() and b.blocked_id = posts.author_id
  )
);

drop policy if exists "comments readable" on comments;
create policy "comments readable" on comments for select to authenticated
using (
  not exists (
    select 1 from user_blocks b
    where b.blocker_id = auth.uid() and b.blocked_id = comments.author_id
  )
);
