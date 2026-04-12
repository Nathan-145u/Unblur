# Research — RSS Sync

## Relevant Files
- `supabase/functions/sync-rss/index.ts` — Edge Function to implement (does not exist yet)
- `supabase/functions/_shared/cors.ts` — Shared CORS headers (does not exist yet)
- `supabase/migrations/` — SQL migration for `episodes` table (does not exist yet)
- `docs/SCHEMA.md` — Canonical schema definition for `episodes` table
- `docs/VERSION_PLAN.md` — Edge Function API contract, response envelope, error codes

## Existing Patterns
- No existing code — fresh Xcode template project. This is the first feature to implement.
- VERSION_PLAN defines the response envelope format: `{ "data": {...}, "error": null }` for all Edge Functions.
- VERSION_PLAN defines CORS pattern: shared headers in `_shared/cors.ts`, `OPTIONS` preflight handling per function.

## Potential Conflicts
- None — no existing Edge Functions or database tables.

## Dependencies
- **SCHEMA.md** — `episodes` table DDL (already defined)
- **VERSION_PLAN** — Edge Function API contract (already defined)
- **Supabase project** — Must be created and configured before implementation (manual step)
- **RSS feed** — `https://feeds.megaphone.fm/STHZE1330487576` (hardcoded)

## Technical Approach Options
- **Option A: Full Edge Function with XML parsing** — Parse RSS XML in Deno, extract episode metadata, upsert into `episodes` table. Pros: self-contained, no external dependencies beyond Supabase SDK. Cons: must handle XML parsing in Deno.
- **Option B: Use a third-party RSS parsing library** — Use a Deno-compatible RSS/XML parser. Pros: less parsing code. Cons: dependency on third-party library availability in Deno.
- **Recommended:** Option A with a lightweight XML parser (Deno has XML parsing capabilities). RSS XML is well-structured and predictable — a full library may be unnecessary.

## Risk Assessment
- **Security:** Edge Function uses `service_role` key internally for DB writes. No user input beyond triggering the sync. Low risk.
- **Performance:** RSS feed parsing is lightweight. Upsert logic prevents duplicates. No performance concerns at this scale (~200 episodes max).
- **Compatibility:** No existing features to break. This is the foundational feature.
