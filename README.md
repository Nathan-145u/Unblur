# Unblur

Native podcast-based English learning app.

## Prerequisites

- Xcode 26.0+
- iOS 17+ / macOS 14+ deployment target
- [supabase-swift](https://github.com/supabase/supabase-swift) (added via SPM, resolved automatically by Xcode)

## Environment Setup

| Variable | Purpose | Where to find | File |
|---|---|---|---|
| `SUPABASE_URL` | Supabase project URL | Supabase Dashboard > Settings > API > Project URL | `ios/Config/Supabase.xcconfig` |
| `SUPABASE_ANON_KEY` | Supabase anonymous (public) key | Supabase Dashboard > Settings > API > anon public | `ios/Config/Supabase.xcconfig` |

### Setup steps

1. Copy the template and fill in your values:
   ```bash
   cp ios/Config/Supabase.xcconfig.example ios/Config/Supabase.xcconfig
   ```
2. Edit `ios/Config/Supabase.xcconfig` with your Supabase project URL and anon key.
3. This file is gitignored — never commit it.

## Getting Started

1. Clone the repository
2. Complete [Environment Setup](#environment-setup)
3. Open `ios/Unblur.xcodeproj` in Xcode
4. Wait for SPM to resolve dependencies
5. Build and run (Cmd+R)

## End-to-End Tests (Maestro)

Per [ADR-006](docs/DECISIONS.md#adr-006-ios-e2e-testing--maestro), iOS E2E flows use Maestro.

### One-time setup

```bash
brew install openjdk@17
curl -Ls "https://get.maestro.mobile.dev" | bash   # installs to ~/.maestro/bin
export JAVA_HOME=$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$HOME/.maestro/bin:$PATH"
```

### Run the suite

```bash
# Boot a simulator and build the app once
xcrun simctl boot "iPhone 17" || true
xcodebuild -project ios/Unblur.xcodeproj -scheme Unblur \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath ios/build build

# Install the built app
xcrun simctl install booted \
  ios/build/Build/Products/Debug-iphonesimulator/Unblur.app

# Run all flows
maestro test maestro/002-episode-list/
```

Flows use a mock `EpisodeService` switched on by the `UITEST_MODE` launch argument — no Supabase credentials needed.
