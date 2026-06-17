# The Evangelist — Technical Documentation

> A mobile app that helps Christians share the Gospel, track their outreach, follow up with new believers, and connect them to local churches. "A movement you can track."

This folder is the engineering source of truth for building **The Evangelist** on **Flutter (iOS + Android)** with a **Supabase (Postgres)** backend.

## Document index

| # | Document | What's inside |
|---|----------|---------------|
| 00 | [Overview](00-overview.md) | Product summary, goals, tech stack, glossary, how the docs fit together |
| 01 | [Architecture](01-architecture.md) | System diagram, components, data flow, realtime, offline, environments |
| 02 | [Data Model](02-data-model.md) | Every table, column, type, relationship, enum, and index (with ER overview) |
| 03 | [Security & RLS](03-security-rls.md) | Auth, Row-Level Security policies per table, privacy rules for the live map |
| 04 | [Backend Logic & APIs](04-backend-logic.md) | Edge Functions, scheduled jobs, AI, realtime presence, nearby-evangelist queries, push |
| 05 | [Feature Specs](05-feature-specs.md) | Per-screen behaviour, data sources, writes, realtime, and edge cases |
| 07 | [Mac → App Store (iOS)](07-mac-to-appstore.md) | Build the app on a Mac (AI-assisted) and publish it to Apple's App Store |
| 08 | [Mac → Google Play (Android)](08-android-to-googleplay.md) | Build & publish the same codebase to Android, plus a cross-platform parity checklist |

## Runnable SQL

| File | Purpose |
|------|---------|
| [`/supabase/schema.sql`](../supabase/schema.sql) | Complete schema: extensions, enums, tables, indexes, triggers. Run first. |
| [`/supabase/policies.sql`](../supabase/policies.sql) | Row-Level Security policies + helper functions. Run second. |

## Quick start for a developer

1. Create a Supabase project (Postgres 15+). Enable the `postgis`, `pgcrypto`, and `pg_cron` extensions.
2. Run `supabase/schema.sql`, then `supabase/policies.sql` in the SQL editor.
3. Create a Flutter app, add the `supabase_flutter` package, and point it at your project URL + anon key.
4. Wire screens to the queries described in [05-feature-specs.md](05-feature-specs.md).
5. Deploy the Edge Functions in [04-backend-logic.md](04-backend-logic.md) and schedule the cron jobs.

See the master Word specification (`The_Evangelist_Technical_Spec.docx`) for a single shareable document covering all of the above.
