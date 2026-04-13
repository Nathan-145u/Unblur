# Unblur

Podcast transcription and translation app for English learners.

## Getting Started

### Prerequisites

- Xcode 26.3+
- iOS 26.2+ simulator or device
- A Supabase project with the migrations applied

### Setup

1. **Clone the repo**

   ```bash
   git clone <repo-url> && cd Unblur
   ```

2. **Configure credentials**

   ```bash
   cp .env.example .env
   ```

   Edit `.env` with your Supabase project URL and anon key:

   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```

3. **Generate config files**

   ```bash
   ./scripts/sync-env.sh
   ```

   This generates `ios/Unblur/Config/Secrets.swift` (gitignored) from your `.env`.
   The Xcode build phase also runs this automatically before each build.

4. **Open and build**

   ```bash
   open ios/Unblur.xcodeproj
   ```

   Select an iOS simulator and build (Cmd+B). SPM dependencies resolve automatically on first build.

5. **Sync episodes**

   The app fetches episodes from Supabase. To populate the database, invoke the `sync-rss` Edge Function:

   ```bash
   supabase functions invoke sync-rss --project-ref your-project-ref
   ```

### Running Tests

```bash
cd ios
xcodebuild -project Unblur.xcodeproj -scheme Unblur \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Project Structure

```
.env                  # Credentials (gitignored, single source of truth)
.env.example          # Template for .env
scripts/sync-env.sh   # Generates config files from .env
ios/                  # iOS app (SwiftUI)
  Unblur/
    Config/           # Generated Secrets.swift (gitignored)
    Models/           # Data transfer objects
    Services/         # Supabase client, repository, network monitor
    ViewModels/       # Observable view models
    Views/            # SwiftUI views
  UnblurTests/        # Unit tests (Swift Testing)
supabase/             # Edge Functions and migrations
specs/                # Feature specs (SDD)
docs/                 # Architecture docs
maestro/              # E2E tests
```
