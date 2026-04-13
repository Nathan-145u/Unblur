# Spec — Episode List

## 1. Scope

**Included:**
- iOS project restructure: move from root `Unblur/` to `ios/` subdirectory
- Supabase Swift SDK integration (read-only, `anon` key)
- Episode list screen: fetch and display episodes from `episodes_view`
- Composite cursor pagination `(publish_date, id)`, 30 episodes per page
- Infinite scroll (load next page near bottom)
- Pull-to-refresh (triggers `sync-rss` Edge Function, then re-fetches list)
- Episode row: title, publish date, duration
- Artwork display via `AsyncImage`
- Basic offline handling: empty list when no network
- Loading and error states

**Excluded:**
- Audio download (003-audio-download)
- Audio playback (004-audio-player)
- SwiftData `LocalEpisode` persistence (003 scope — no downloads in 002)
- Search / filter
- Settings screen
- Mini player / full player

## 2. Technical Context & Constraints

- **Runtime:** iOS 17+ / iPadOS 17+ / macOS 14+, SwiftUI
- **Data source:** Supabase `episodes_view` via Supabase Swift SDK
- **Auth:** `anon` key in `Authorization: Bearer` header (SDK handles this)
- **Pagination:** Composite cursor `(publish_date DESC, id DESC)`, 30 per page
- **Prerequisite features:** 001-rss-sync (episodes exist in DB)
- **Design:** Stock SwiftUI + accent color `#F28C38`, SF Symbols, SF Pro typography (see DESIGN.md)
- **Supabase config:** `SUPABASE_URL` and `SUPABASE_ANON_KEY` via Xcode build configuration / Info.plist

## 3. Functional Requirements

### 3.1 App Launch

1. App launches → show episode list screen as root view
2. Immediately fetch first page (30 episodes) from `episodes_view`, ordered by `publish_date DESC, id DESC`
3. While loading: show centered `ProgressView`
4. On success: display episode list
5. On failure: show error message with retry button

### 3.2 Episode Row

Each row displays:
- **Title** — primary text, up to 2 lines
- **Publish date** — secondary text, formatted as relative date (e.g., "Yesterday", "3 days ago") for dates within 7 days, otherwise "Apr 12, 2026"
- **Duration** — secondary text, formatted as `MM:SS` or `H:MM:SS`
- **Artwork** — thumbnail via `AsyncImage`, placeholder while loading

Row is non-interactive in 002 (no tap action — download and playback are 003/004 scope).

### 3.3 Infinite Scroll

1. When user scrolls within 5 items of the bottom, trigger next page fetch
2. Next page query: `WHERE (publish_date, id) < (cursor_date, cursor_id) ORDER BY publish_date DESC, id DESC LIMIT 30`
3. Append new episodes to existing list
4. If returned count < 30, mark as "no more pages" and stop loading
5. Show a small loading indicator at list bottom while fetching

### 3.4 Pull-to-Refresh

1. User pulls down → call `sync-rss` Edge Function (POST)
2. After sync completes (success or failure), re-fetch first page from `episodes_view`
3. Replace entire list with fresh data, reset pagination cursor
4. If sync fails, still re-fetch list (show what's in DB), but show a brief error toast

### 3.5 Offline Handling

Principle: if data is already loaded, don't disturb the user. Only show offline messaging when there's no data or the user actively requests new data.

1. **Has data + offline:** Keep displaying the loaded list as-is. No banner, no clearing.
2. **Pull-to-refresh + offline:** Show brief error toast "No internet connection". Keep existing data.
3. **Load next page + offline:** Show inline error at list bottom. Keep existing data.
4. **First launch + offline + no data:** Show empty state "No internet connection".
5. **Network restored:** No auto-retry. User can pull-to-refresh manually.

### 3.6 Navigation

- `NavigationStack` with title "Unblur"
- No toolbar items in 002 (settings, storage management are future scope)

## 4. Error Handling Table

| Scenario | Behavior | Component |
|----------|----------|-----------|
| Initial fetch fails (network error) | Show centered error message + retry button | EpisodeListView |
| Initial fetch fails (non-200 response) | Show centered error message + retry button | EpisodeListView |
| Next page fetch fails | Show inline error at list bottom + retry button, keep existing data | EpisodeListView |
| Pull-to-refresh sync-rss fails | Show brief toast "Sync failed", still re-fetch list from DB | EpisodeListView |
| Pull-to-refresh list re-fetch fails | Show brief toast "Failed to load episodes" | EpisodeListView |
| No network on launch | Show empty state "No internet connection" | EpisodeListView |
| Artwork URL returns error | Show placeholder image (SF Symbol `waveform`) | EpisodeRowView |
| Empty database (no episodes synced yet) | Show empty state "No episodes yet. Pull down to sync." | EpisodeListView |

## 5. Acceptance Criteria

- [ ] iOS project lives in `ios/` subdirectory, builds and runs from Xcode
- [ ] App launches and fetches first 30 episodes from Supabase `episodes_view`
- [ ] Episodes are sorted by `publish_date DESC`
- [ ] Each row shows title (max 2 lines), formatted date, formatted duration, and artwork thumbnail
- [ ] Scrolling near bottom triggers next page load; new episodes append to list
- [ ] Composite cursor `(publish_date, id)` prevents duplicate or missing episodes at page boundaries
- [ ] When all episodes are loaded, no further requests are made
- [ ] Pull-to-refresh calls `sync-rss` then reloads the list
- [ ] Network error on initial load shows error + retry button
- [ ] Offline shows "No internet connection" empty state
- [ ] Empty database shows "No episodes yet. Pull down to sync."
- [ ] Supabase credentials are NOT hardcoded in source (Info.plist / build config)

## 6. Critical Path

1. Restructure iOS project to `ios/` subdirectory
2. Integrate Supabase Swift SDK, configure credentials via build config
3. Implement `EpisodeListViewModel` with pagination logic
4. Build `EpisodeListView` + `EpisodeRowView`
5. Wire pull-to-refresh → sync-rss → re-fetch
6. Add offline detection + empty states
7. Verify all acceptance criteria on device/simulator
