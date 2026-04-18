# Plan — Episode List

## Prerequisites
- 001-rss-sync: complete (all 4 tickets done) — episodes exist in Supabase

## Technical Approach

### Architecture: Service + ViewModel

```
EpisodeListView (SwiftUI)
    │
    ▼
EpisodeListViewModel (@Observable)
    │  - manages LoadState (idle/loading/loaded/error)
    │  - manages pagination cursor + hasMore flag
    │  - exposes episodes array, load/refresh/loadMore methods
    │
    ▼
EpisodeService (protocol)
    │
    ├── SupabaseEpisodeService (production — calls Supabase SDK)
    └── MockEpisodeService (tests — returns hardcoded data)
```

- **EpisodeService protocol:** Defines `fetchEpisodes(cursor: (Date, UUID)?, limit: Int) async throws -> [Episode]`
- **SupabaseEpisodeService:** Implements the protocol using Supabase Swift SDK to query `episodes_view`
- **EpisodeListViewModel:** @Observable class managing load state, episode array, composite cursor, pagination logic
- **EpisodeListView:** SwiftUI view observing ViewModel, renders list with all states (loading, loaded, empty, error, offline)
- **Episode model:** Decodable struct matching `episodes_view` columns
- **Formatters:** Duration formatter and relative date formatter as utility extensions

### Supabase Swift SDK Integration

- Add `supabase-swift` package via Swift Package Manager
- Configure `SupabaseClient` singleton with URL + anon key from build configuration
- Anon key and URL stored in Xcode build configuration (`.xcconfig`), never hardcoded

### Composite Cursor Pagination (Supabase SDK)

Supabase PostgREST SDK supports row-value comparison via `.lt`:
```
supabase.from("episodes_view")
    .select()
    .order("publish_date", ascending: false)
    .order("id", ascending: false)
    .lt("publish_date", value: cursorDate)  // simplified — actual implementation uses .or() for composite
    .limit(30)
```

Note: True composite cursor `(publish_date, id) < (:date, :id)` requires an `.or()` filter or `.rpc()` call since PostgREST doesn't natively support row-value comparison. Implementation will use:
```
.or("publish_date.lt.\(cursorDate),and(publish_date.eq.\(cursorDate),id.lt.\(cursorId))")
```

### Project Setup

- Remove Xcode template files (`Item.swift`)
- Replace `ContentView.swift` with `EpisodeListView`
- Update `UnblurApp.swift` to remove `Item` model container (SwiftData not needed in 002 — introduced in 003)
- Supabase URL + anon key: defined once in `.xcconfig` file, referenced via `Info.plist`, read from `Bundle.main` at runtime. `.xcconfig` added to `.gitignore`.
- Accent color `#F28C38`: defined in `Assets.xcassets` as the `AccentColor` Color Set (supports Light/Dark Mode). SwiftUI uses `Color.accentColor` / `.tint()` globally.

## File Change List
- Move: `Unblur/` → `ios/` — Project directory migration (T006)
- Add: `ios/Unblur/Models/Episode.swift` — Decodable model matching episodes_view
- Add: `ios/Unblur/Services/EpisodeService.swift` — Protocol + SupabaseEpisodeService implementation
- Add: `ios/Unblur/Services/SupabaseClient.swift` — Singleton client configuration
- Add: `ios/Config/Supabase.xcconfig` — Supabase URL + anon key (gitignored)
- Add: `ios/Unblur/ViewModels/EpisodeListViewModel.swift` — State management + pagination
- Add: `ios/Unblur/Views/EpisodeListView.swift` — Main list screen with all states
- Add: `ios/Unblur/Views/EpisodeRowView.swift` — Single episode row component
- Add: `ios/Unblur/Utilities/DurationFormatter.swift` — Duration formatting (seconds → "12m" / "1h 5m")
- Add: `ios/Unblur/Utilities/RelativeDateFormatter.swift` — Date formatting (Today / Yesterday / X days ago / etc.)
- Modify: `ios/Unblur/UnblurApp.swift` — Remove Item/SwiftData, set up SupabaseClient, use EpisodeListView
- Modify: `README.md` — Add prerequisites and environment setup for Supabase
- Delete: `ios/Unblur/Item.swift` — Xcode template placeholder
- Delete: `ios/Unblur/ContentView.swift` — Replaced by EpisodeListView
- Add: `ios/UnblurTests/EpisodeListViewModelTests.swift` — ViewModel unit tests
- Add: `ios/UnblurTests/DurationFormatterTests.swift` — Duration formatting tests
- Add: `ios/UnblurTests/RelativeDateFormatterTests.swift` — Date formatting tests
