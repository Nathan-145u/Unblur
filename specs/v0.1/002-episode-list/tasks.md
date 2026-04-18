# Tasks — Episode List

## T006: Migrate iOS project to ios/ subdirectory
- Status: done
- Files: `Unblur/` → `ios/`, `Unblur.xcodeproj`
- Done Definition: iOS project moved from `Unblur/` to `ios/` per VERSION_PLAN repo structure. Xcode project opens and builds from `ios/` path. All internal references (source files, assets, tests) resolve correctly.
- Dependencies: none
- Manual Intervention: none

## T007: Project setup + Supabase SDK integration
- Status: done
- Files: `ios/Unblur.xcodeproj` (SPM dependency), `ios/Unblur/Services/SupabaseClient.swift`, `ios/Config/Supabase.xcconfig`, `ios/Info.plist`, `.gitignore`, `README.md`
- Done Definition: `supabase-swift` added via SPM. SupabaseClient singleton reads URL + anon key from Info.plist (via xcconfig). xcconfig added to .gitignore. README.md updated: Prerequisites lists `supabase-swift` dependency, Environment Setup documents SUPABASE_URL and SUPABASE_ANON_KEY (where to find values, which file to put them in). App builds without errors.
- Dependencies: T006
- Manual Intervention: [HUMAN REQUIRED] Create `ios/Config/Supabase.xcconfig` with actual SUPABASE_URL and SUPABASE_ANON_KEY values from Supabase Dashboard.

## T008: Episode model + EpisodeService
- Status: done
- Files: `ios/Unblur/Models/Episode.swift`, `ios/Unblur/Services/EpisodeService.swift`
- Done Definition: `Episode` struct is Decodable and matches `episodes_view` columns. `EpisodeService` protocol defines `fetchEpisodes(cursor:limit:)`. `SupabaseEpisodeService` implements composite cursor pagination via `.or()` filter. Unit test verifies mock service returns expected data.
- Dependencies: T007
- Manual Intervention: none

## T009: Duration + date formatters
- Status: done
- Files: `ios/Unblur/Utilities/DurationFormatter.swift`, `ios/Unblur/Utilities/RelativeDateFormatter.swift`, `ios/UnblurTests/DurationFormatterTests.swift`, `ios/UnblurTests/RelativeDateFormatterTests.swift`
- Done Definition: Duration formatter handles 0 → "—", <3600 → "Xm", ≥3600 → "Xh Ym". Relative date formatter handles Today/Yesterday/X days ago/Mon DD/Mon DD, YYYY. All test cases pass.
- Dependencies: none
- Manual Intervention: none

## T010: EpisodeListViewModel
- Status: done
- Files: `ios/Unblur/ViewModels/EpisodeListViewModel.swift`, `ios/UnblurTests/EpisodeListViewModelTests.swift`
- Done Definition: @Observable ViewModel manages LoadState (idle/loading/loaded/error). Supports initial load, pagination (with isLoadingMore guard), pull-to-refresh (resets cursor). Composite cursor updated after each page. hasMore set to false when page < 30 items. Tests cover: initial load success/failure, pagination appends data, refresh resets state, duplicate pagination calls ignored.
- Dependencies: T008, T009
- Manual Intervention: none

## T011: EpisodeListView + EpisodeRowView
- Status: done
- Files: `ios/Unblur/Views/EpisodeListView.swift`, `ios/Unblur/Views/EpisodeRowView.swift`, `ios/Unblur/Assets.xcassets` (AccentColor), `ios/Unblur/ViewModels/EpisodeListViewModel.swift` (paginationFailed/refreshFailed signals — scope extended per spec §3.3/§4 banner requirement), `ios/UnblurTests/EpisodeListViewModelTests.swift` (error signal tests)
- Done Definition: List displays episodes with artwork (AsyncImage 60×60, placeholder waveform), title (2-line max), relative date, formatted duration. Infinite scroll triggers loadMore at last 5 items. Pull-to-refresh via .refreshable. All states rendered: loading (centered spinner), loaded (list), empty ("No episodes yet"), error ("Unable to load episodes" + retry), offline ("No internet connection" + retry). AccentColor #F28C38 set in Asset Catalog.
- Dependencies: T010
- Manual Intervention: none

## T012: App entry point cleanup
- Status: done
- Files: `ios/Unblur/UnblurApp.swift`
- Done Definition: SwiftData/Item references removed. App root view is EpisodeListView with ViewModel injected. App launches and displays episode list from Supabase. Item.swift and ContentView.swift deleted.
- Dependencies: T011
- Manual Intervention: none

## T014: Artwork image loader (downsample + cache)
- Status: done
- Files: `ios/Unblur.xcodeproj` (SPM dependency), `ios/Unblur/Views/EpisodeRowView.swift`, `docs/DECISIONS.md`
- Done Definition: Nuke added via SPM. `EpisodeRowView` replaces `AsyncImage` with `NukeUI.LazyImage` configured with `ImageProcessors.Resize` at 120×120px (2× of 60pt display). Memory with 30 episodes loaded stays under 200 MB (baseline ~700 MB with `AsyncImage`). Scrolling through 100+ episodes is smooth — no main-thread image decoding. Artwork placeholder still shown when URL is nil or load fails. DECISIONS.md records the Nuke choice and reasoning.
- Dependencies: T012
- Manual Intervention: none

## T013: Integration test
- Status: planned
- Files: none
- Done Definition: All acceptance criteria in spec.md verified — app launches, list loads from Supabase, pagination works (no skipped/duplicated episodes), pull-to-refresh works, all error states display correctly, artwork placeholders shown when needed, duration "0" shows "—", scrolling is smooth and memory stays under 200 MB with 30 episodes loaded. Tested on iOS Simulator.
- Dependencies: T014
- Manual Intervention: none
