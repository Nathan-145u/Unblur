# Plan — RSS Sync

## Prerequisites

- No cross-feature dependencies (first feature in the project)

## Technical Approach

- **RSS parsing:** Use Deno's built-in XML parsing or a lightweight XML parser to extract episode data from the RSS feed. Parse `<item>` elements and map to `episodes` table columns.
- **Upsert strategy:** Use Supabase JS client's `upsert()` with `onConflict: 'remote_audio_url'`. This handles both insert (new episodes) and update (changed metadata) in a single operation.
- **Duration parsing:** Implement a helper function that handles three formats: `HH:MM:SS`, `MM:SS`, and raw seconds (integer string). Returns integer seconds.
- **Artwork fallback:** Extract channel-level `<itunes:image>` first, then override with episode-level if present.
- **CORS:** Deferred to v0.2 when Web Admin is introduced. v0.1 only has iOS callers, which are not subject to CORS.
- **Error boundaries:** Wrap RSS fetch and XML parse in separate try/catch blocks to distinguish `RSS_FETCH_FAILED` (502) from `RSS_PARSE_ERROR` (500). Individual episode parse failures are silently skipped.
- **Migration:** Single SQL migration file creates `episodes` table (with v0.2/v0.3 pre-created columns per CONSTITUTION.md deviation), indexes, `episodes_view`, and RLS policies. DDL follows SCHEMA.md §SQL DDL exactly.

## File Change List

- Add: `supabase/config.toml` — Supabase project configuration
- Add: `supabase/functions/sync-rss/index.ts` — Edge Function implementation
- Add: `supabase/migrations/<timestamp>_create_episodes.sql` — Database migration
