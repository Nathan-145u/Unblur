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
