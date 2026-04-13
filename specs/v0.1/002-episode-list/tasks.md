# Tasks — Episode List

## T005: iOS project restructure
- Status: planned
- Files: `ios/Unblur/`, `ios/Unblur.xcodeproj/`
- Done Definition: iOS project moved to `ios/` subdirectory. `xcodebuild` succeeds from `ios/`. Old root `Unblur/` and `Unblur.xcodeproj/` removed.
- Dependencies: none
- Manual Intervention: none

## T006: Supabase Swift SDK integration + credentials management
- Status: planned
- Files: `.env`, `.env.example`, `.gitignore`, `scripts/sync-env.sh`, `ios/Unblur/Config/Secrets.xcconfig`, `ios/Unblur/Services/SupabaseClient.swift`
- Done Definition: Root `.env` is the single source of truth for all credentials (ADR-009). `scripts/sync-env.sh` reads `.env` and generates `ios/Unblur/Config/Secrets.xcconfig` (and future `admin/.env.local`). Xcode Build Phase runs `sync-env.sh` automatically before compilation. `supabase-swift` added via SPM. `SupabaseClient` singleton reads URL and anon key from Info.plist (injected via `.xcconfig`). `.env` and generated config files gitignored. `.env.example` committed with placeholder values.
- Dependencies: T005
- Manual Intervention: [HUMAN REQUIRED] Create root `.env` with real Supabase URL and anon key (template provided in `.env.example`)

## T007: Data layer (EpisodeDTO + EpisodeRepository)
- Status: planned
- Files: `ios/Unblur/Models/EpisodeDTO.swift`, `ios/Unblur/Services/EpisodeRepository.swift`
- Done Definition: `EpisodeDTO` decodes all `episodes_view` columns. `EpisodeRepository` fetches paginated episodes with composite cursor `(publish_date, id)` and calls `sync-rss` for refresh. Unit tests verify pagination logic and DTO decoding.
- Dependencies: T006
- Manual Intervention: none

## T008: Network monitor
- Status: planned
- Files: `ios/Unblur/Services/NetworkMonitor.swift`
- Done Definition: `NetworkMonitor` (@Observable) wraps `NWPathMonitor`, exposes `isConnected: Bool`. Updates on main thread.
- Dependencies: T005
- Manual Intervention: none

## T009: EpisodeListViewModel
- Status: planned
- Files: `ios/Unblur/ViewModels/EpisodeListViewModel.swift`
- Done Definition: ViewModel manages episodes array, loading/error/pagination state, infinite scroll trigger, pull-to-refresh flow. Unit tests verify state transitions.
- Dependencies: T007, T008
- Manual Intervention: none

## T010: EpisodeListView + EpisodeRowView
- Status: planned
- Files: `ios/Unblur/Views/EpisodeListView.swift`, `ios/Unblur/Views/EpisodeRowView.swift`, `ios/Unblur/UnblurApp.swift`
- Done Definition: List displays episodes with title, date, duration, artwork. Infinite scroll loads next page. Pull-to-refresh syncs and reloads. Error/empty/offline states render correctly. App root is `EpisodeListView`.
- Dependencies: T009
- Manual Intervention: none

## T011: Tests
- Status: planned
- Files: `ios/UnblurTests/EpisodeDTOTests.swift`, `ios/UnblurTests/EpisodeRepositoryTests.swift`, `ios/UnblurTests/EpisodeListViewModelTests.swift`, `maestro/002-episode-list.yaml`
- Done Definition: XCTest unit tests pass — DTO decoding (valid/missing fields), Repository pagination cursor logic (mock), ViewModel state transitions (loading/success/error/pagination). Maestro E2E test passes — app launches, list loads, scroll triggers next page, pull-to-refresh updates list.
- Dependencies: T010
- Manual Intervention: none

## T012: README setup guide
- Status: planned
- Files: `README.md`
- Done Definition: README contains Getting Started section covering: clone, .env setup, sync-env.sh, Xcode build, Supabase link. A new developer can set up the project by following the guide.
- Dependencies: T006
- Manual Intervention: none
