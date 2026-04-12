# Tasks — RSS Sync

## T001: Supabase project setup
- Status: in_progress
- Files: `supabase/config.toml`
- Done Definition: `supabase init` completed, `config.toml` exists with correct project configuration
- Dependencies: none
- Manual Intervention: [HUMAN REQUIRED] Create Supabase project via dashboard, obtain project URL and keys, link local project with `supabase link`

## T002: Database migration
- Status: planned
- Files: `supabase/migrations/<timestamp>_create_episodes.sql`
- Done Definition: Migration file creates `episodes` table, indexes, `episodes_view`, and RLS policies per SCHEMA.md. `supabase db push` succeeds.
- Dependencies: T001
- Manual Intervention: none

## T003: sync-rss Edge Function
- Status: planned
- Files: `supabase/functions/sync-rss/index.ts`
- Done Definition: Function fetches RSS feed, parses episodes, upserts to database, returns `{ data: { inserted, updated, total }, error: null }`. Error responses use correct HTTP status codes and error codes.
- Dependencies: T002
- Manual Intervention: none

## T004: Integration test
- Status: planned
- Files: none
- Done Definition: All acceptance criteria in spec.md pass — first sync inserts episodes, repeated sync produces no duplicates, error cases return correct codes, RLS prevents anon writes. Tested locally via `supabase functions serve` + `curl`.
- Dependencies: T003
- Manual Intervention: none
