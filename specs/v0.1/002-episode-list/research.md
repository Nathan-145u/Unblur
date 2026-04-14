# Research — Episode List

## Relevant Files
- `supabase/migrations/20260412000000_create_episodes.sql` — Episodes table, `episodes_view`, RLS policies (already deployed)
- `supabase/functions/sync-rss/index.ts` — Populates the episodes table from RSS feed (upstream dependency, complete)
- `docs/SCHEMA.md` — SSOT for database schema; defines `episodes_view` columns: id, title, publish_date, duration, remote_audio_url, artwork_url, source_type, transcription_status, translation_status
- `docs/DESIGN.md` — iOS design language: stock SwiftUI + custom orange accent `#F28C38`, SF Symbols, large corner radius
- `Unblur/UnblurApp.swift` — Existing Xcode template app entry point (SwiftData + default Item model)
- `Unblur/ContentView.swift` — Xcode template placeholder (NavigationSplitView with Item list)
- `Unblur/Item.swift` — Xcode template data model (to be replaced)

## Existing Patterns
- **Data access:** iOS reads from Supabase views via Swift SDK with `anon` key (VERSION_PLAN §Data Access Pattern)
- **Pagination:** Cursor-based, 30 episodes per page, sorted by `publish_date DESC`, cursor is `publish_date` of last item (VERSION_PLAN §Pagination)
- **Offline behavior:** Show downloaded episodes from SwiftData when offline; full-screen "No internet connection" when offline + no downloads (VERSION_PLAN §Offline Behavior)
- **Local storage:** `LocalEpisode` SwiftData model caches episode metadata at download time (VERSION_PLAN §Offline Behavior)
- **Edge Function response envelope:** `{ data: { ... }, error: null }` / `{ data: null, error: { code, message } }`

## Potential Conflicts
- **Project structure:** iOS project currently lives at `Unblur/` (repository root). VERSION_PLAN specifies `ios/` subdirectory. Migration should happen as part of v0.1 setup, but is NOT in scope for this feature spec (it's a project-level task).
- **Xcode template code:** `Item.swift`, `ContentView.swift` are Xcode defaults — will be replaced entirely, no conflict.
- **SwiftData schema:** Template uses `Item.self` in ModelContainer. Feature will introduce `LocalEpisode` model. No conflict since `Item` will be removed.

## Dependencies
- **001-rss-sync** (complete): Episodes must exist in Supabase before the list can display them.
- **SCHEMA.md `episodes_view`**: Defines the read API contract — the iOS model must match these columns.
- **Supabase Swift SDK**: `supabase-swift` package — needs to be added to the Xcode project.
- **003-audio-download** (downstream): Episode list rows will show download state, but that's 003's scope. This feature only displays episode metadata.
- **004-audio-player** (downstream): Tapping an episode will eventually play it, but playback is 004's scope. This feature defines the navigation structure.

## Technical Approach Options

### Option A: Direct Supabase SDK calls in View
- SwiftUI views call Supabase SDK directly using `.task` modifier
- **Pros:** Simplest, least code, fast to ship
- **Cons:** No testability, no separation of concerns, hard to add offline support later

### Option B: Service layer + @Observable ViewModel
- `EpisodeService` protocol handles Supabase calls
- `EpisodeListViewModel` (@Observable) manages state (loading, loaded, error, pagination)
- Views observe the ViewModel
- **Pros:** Testable, clean separation, aligns with Swift rules (protocol-oriented DI), ready for offline support in 003
- **Cons:** Slightly more code upfront

### Option C: SwiftData as primary store + background sync
- Sync all episodes into SwiftData, views always read from SwiftData
- **Pros:** Full offline support from day one, smooth animations with SwiftData queries
- **Cons:** Over-engineering for v0.1 — offline for episode *list* isn't needed until downloads exist (003). Adds sync complexity.

### Recommended: Option B
- Aligns with project rules (protocol-oriented design, DI, testability)
- Prepares for 003-audio-download without over-engineering
- ViewModel pattern is idiomatic SwiftUI
- Service protocol enables unit testing with mock Supabase responses

## Risk Assessment
- **Security:** Low risk. Only reads from Supabase via `anon` key (SELECT-only RLS). No user input, no writes.
- **Performance:** Pagination (30 per page) prevents loading hundreds of episodes at once. Artwork loading should use `AsyncImage` with caching.
- **Compatibility:** No impact on existing features (001-rss-sync is backend-only). New iOS code replaces Xcode template.
