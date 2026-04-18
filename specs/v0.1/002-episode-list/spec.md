# Spec — Episode List

## 1. Scope

**Included:**
- iOS app fetches and displays episodes from Supabase `episodes_view`
- Cursor-based pagination (30 per page, infinite scroll)
- Pull-to-refresh to reload from the top
- Loading, error, empty, and offline states
- Supabase Swift SDK integration and project configuration
- Replace Xcode template code (Item.swift, ContentView.swift) with episode list

**Excluded:**
- Audio download (003-audio-download)
- Audio playback and player UI (004-audio-player)
- Offline episode list from SwiftData (003 — no downloaded episodes exist yet)
- Tap-to-play interaction (004 — episode rows are non-interactive in 002)
- Web Admin episode list (v0.2 scope)
- Project directory migration (`Unblur/` → `ios/`) — included as a prerequisite task (T006) but not part of the episode list feature scope itself

## 2. Technical Context & Constraints

- **Platform:** iOS 17+ / iPadOS 17+ / macOS 14+, SwiftUI
- **Data source:** Supabase `episodes_view` via Swift SDK, `anon` key (read-only)
- **Pagination:** Composite cursor `(publish_date, id)`, 30 per page, `ORDER BY publish_date DESC, id DESC` (see §3.2)
- **Architecture:** Service protocol + @Observable ViewModel (see research.md Option B)
- **Design:** Stock SwiftUI components, custom orange accent `#F28C38`, SF Symbols (per DESIGN.md)
- **Prerequisite features:** 001-rss-sync (complete) — episodes must exist in Supabase
- **Schema reference:** [SCHEMA.md](../../../docs/SCHEMA.md) `episodes_view` — id, title, publish_date, duration, remote_audio_url, artwork_url, source_type, transcription_status, translation_status

## 3. Functional Requirements

### 3.1 Episode List Screen

The episode list is the app's root screen. It displays episodes sorted by publish date (newest first).

**Row layout:**
- **Leading:** Episode artwork (async image loader with downsampling to 2× display size and in-memory caching, 60×60pt, corner radius 8pt, placeholder: SF Symbol `waveform`)
- **Title:** Episode title (primary text, 2-line max, truncated)
- **Subtitle line:** Publish date (relative format: "Today", "Yesterday", "3 days ago", etc.) + duration (formatted: `12m` or `1h 5m`)
- **No trailing accessory** (no chevron, no download button — those come in 003/004)

**Navigation:**
- `NavigationStack` at root
- Navigation title: "Unblur"
- No detail view in this feature — tapping a row does nothing (placeholder for 004)

### 3.2 Pagination

- **Composite cursor:** `(publish_date, id)` — guarantees unique ordering even when multiple episodes share the same timestamp
- **Page size:** 30
- **First page query:** `SELECT * FROM episodes_view ORDER BY publish_date DESC, id DESC LIMIT 30`
- **Subsequent pages:** `SELECT * FROM episodes_view WHERE (publish_date, id) < (:cursor_date, :cursor_id) ORDER BY publish_date DESC, id DESC LIMIT 30`
- **Trigger:** When the user scrolls to the last 5 items in the list, load the next page
- **End detection:** When a page returns fewer than 30 items, set `hasMore = false` and stop loading
- **Pagination indicator:** A `ProgressView` at the bottom of the list while loading the next page

### 3.3 Pull-to-Refresh

- Standard SwiftUI `.refreshable` modifier
- During refresh: existing list remains visible (no clearing)
- On success: replaces list with fresh data from the first page, resets cursor
- On failure: keeps existing list, shows an inline error banner

### 3.4 Initial Load

- On app launch, automatically fetch the first page
- Show a centered `ProgressView` while loading (full-screen, no list visible)
- On success: display the episode list
- On failure: show error state (§3.6)

### 3.5 Empty State

- When the first page returns 0 episodes
- Centered message: SF Symbol `tray` (48pt) + "No episodes yet" + "Pull down to refresh"

### 3.6 Error State

- When the initial load fails (network error, Supabase error)
- Centered message: SF Symbol `wifi.exclamationmark` (48pt) + "Unable to load episodes" + "Tap to retry" button
- Tapping the button retries the initial load

### 3.7 Offline State

- Detected passively: when the initial Supabase request fails with a network error, show offline state
- Centered message: SF Symbol `wifi.slash` (48pt) + "No internet connection" + "Tap to retry" button
- **Note:** In v0.1 there are no downloaded episodes, so offline always shows this screen. Offline episode list from SwiftData is added in 003. Active network monitoring (`NWPathMonitor`) deferred to 003 where download management needs it.

### 3.8 Duration Formatting

| Duration (seconds) | Display |
|---|---|
| 0 | — (em dash) |
| 1–3599 | `Xm` (e.g., `12m`, `59m`) |
| 3600+ | `Xh Ym` (e.g., `1h 5m`, `2h 0m`) |

Minutes are always rounded down (floor). Zero minutes after hours still displayed (e.g., `2h 0m`).

### 3.9 Date Formatting

| Condition | Display |
|---|---|
| Today | "Today" |
| Yesterday | "Yesterday" |
| Within 7 days | "X days ago" |
| This year | "Mar 15" (short month + day) |
| Previous years | "Mar 15, 2025" (short month + day + year) |

## 4. Error Handling Table

| Scenario | Behavior | Component |
|---|---|---|
| Network unreachable (initial load) | Show offline state with retry (§3.7) | EpisodeListView |
| Supabase SDK error (initial load) | Show error state with retry (§3.6) | EpisodeListView |
| Network unreachable (pagination) | Show inline error at list bottom, keep existing data | EpisodeListView |
| Supabase SDK error (pagination) | Show inline error at list bottom, keep existing data | EpisodeListView |
| Network unreachable (pull-to-refresh) | Show inline error banner, keep existing data | EpisodeListView |
| Supabase SDK error (pull-to-refresh) | Show inline error banner, keep existing data | EpisodeListView |
| Artwork URL nil or load fails | Show placeholder SF Symbol `waveform` | Episode row |
| Duration is 0 | Display "—" instead of "0m" | Episode row |

## 5. Acceptance Criteria

- [ ] App launches and displays a list of episodes fetched from Supabase `episodes_view`
- [ ] Episodes are sorted by `publish_date` descending (newest first)
- [ ] Each row shows artwork, title, relative date, and formatted duration
- [ ] Scrolling near the bottom loads the next 30 episodes (infinite scroll)
- [ ] Composite cursor `(publish_date, id)` is used — no episodes are skipped or duplicated across pages
- [ ] Pull-to-refresh reloads the list from the first page
- [ ] Initial loading state shows a centered spinner
- [ ] Empty state shows "No episodes yet" when no episodes exist
- [ ] Error state shows "Unable to load episodes" with a retry button
- [ ] Offline state shows "No internet connection" when device is offline
- [ ] Pagination error does not clear existing loaded episodes
- [ ] Pull-to-refresh error does not clear existing loaded episodes
- [ ] Artwork placeholder shown when artwork URL is nil or image fails to load
- [ ] Duration "0" displays as "—"
- [ ] Scrolling through 100+ episodes remains smooth (no visible stutter); memory stays under 200 MB with 30 episodes loaded

## 6. Critical Path

1. Launch app with network connected and episodes in Supabase
2. See loading spinner → episode list appears with artwork, title, date, duration
3. Scroll to bottom → next page loads automatically, more episodes appear
4. Pull down → list refreshes with latest data
5. Disconnect network, relaunch app → "No internet connection" screen shown
