# Plan — Episode List

## Prerequisites
- `001-rss-sync` — all tickets done ✅

## Technical Approach

### 1. iOS Project Restructure
Move `Unblur/` and `Unblur.xcodeproj/` to `ios/` subdirectory. Update `.xcodeproj` internal paths. Verify build succeeds.

### 2. Supabase Swift SDK Integration
Add `supabase-swift` SPM package. Create a `SupabaseClient` singleton configured with URL and anon key from Info.plist. No hardcoded credentials.

### 3. Data Layer
- Define `EpisodeDTO` struct (Decodable) matching `episodes_view` columns
- Create `EpisodeRepository` protocol + `SupabaseEpisodeRepository` implementation
- Composite cursor pagination: `(publish_date, id)` descending, 30 per page
- Pull-to-refresh: POST to `sync-rss` Edge Function, then re-fetch first page

### 4. Presentation Layer
- `EpisodeListViewModel` (@Observable): manages episodes array, loading/error/pagination state
- `EpisodeListView`: NavigationStack, List with infinite scroll, pull-to-refresh, empty/error states
- `EpisodeRowView`: title (2 lines), relative date, formatted duration, AsyncImage artwork

### 5. Network Monitoring
- `NetworkMonitor` (@Observable) wrapping `NWPathMonitor`
- Offline → show empty state; online restored → auto-retry

## File Change List
- Move: `Unblur/` → `ios/Unblur/`
- Move: `Unblur.xcodeproj/` → `ios/Unblur.xcodeproj/`
- Add: `ios/Unblur/Config/Supabase.plist` — Supabase URL + anon key (gitignored)
- Add: `ios/Unblur/Config/Supabase.plist.example` — template without real values (committed)
- Add: `ios/Unblur/Services/SupabaseClient.swift` — singleton client
- Add: `ios/Unblur/Models/EpisodeDTO.swift` — Decodable struct for episodes_view
- Add: `ios/Unblur/Services/EpisodeRepository.swift` — protocol + Supabase implementation
- Add: `ios/Unblur/Services/NetworkMonitor.swift` — NWPathMonitor wrapper
- Add: `ios/Unblur/ViewModels/EpisodeListViewModel.swift` — list state management
- Add: `ios/Unblur/Views/EpisodeListView.swift` — main list screen
- Add: `ios/Unblur/Views/EpisodeRowView.swift` — single row
- Modify: `ios/Unblur/UnblurApp.swift` — set EpisodeListView as root, inject dependencies
- Modify: `.gitignore` — add `Supabase.plist`
