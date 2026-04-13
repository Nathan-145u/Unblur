# Research — Episode List

## Relevant Files
- `docs/SCHEMA.md` — `episodes` table, `episodes_view` definition, RLS policies
- `docs/VERSION_PLAN.md` — Pagination spec, offline behavior, `LocalEpisode` SwiftData model, repo structure (`ios/` subdirectory)
- `docs/DESIGN.md` — iOS design language: stock SwiftUI + warm palette, accent `#F28C38`, SF Symbols
- `docs/CONSTITUTION.md` — Offline-friendly principle, SSOT mapping
- `supabase/functions/sync-rss/index.ts` — Upstream dependency: episodes already synced to Supabase

## Existing Patterns
- 001-rss-sync established the Supabase Edge Function pattern. iOS client reads from `episodes_view` via Supabase Swift SDK (not direct table access).
- VERSION_PLAN defines data access rules: reads via Views, writes via Edge Functions or service_role.

## Dependencies
- `001-rss-sync` (done) — Episodes exist in Supabase DB
- Supabase Swift SDK (`supabase-swift`) — For reading `episodes_view`
- iOS project restructure — Move from root `Unblur/` to `ios/` per VERSION_PLAN

## Technical Approach

### Data Fetching
Supabase Swift SDK reading `episodes_view`. Cursor-based pagination with composite cursor `(publish_date, id)` to handle duplicate timestamps.

### State Management
`@Observable` ViewModel holding remote episodes array, loading state, error state. SwiftUI observes changes.

### Offline Strategy
- Online: fetch from Supabase `episodes_view`
- Offline: empty list (no downloads exist yet in 002 scope)
- Network detection via `NWPathMonitor`

## Risk Assessment
- Security: Low. Read-only via `anon` key, RLS enforced server-side.
- Performance: Composite cursor pagination (30/page) keeps payload small. `AsyncImage` for artwork.
- Compatibility: No conflict with 001. Sets up data layer for 003/004.
