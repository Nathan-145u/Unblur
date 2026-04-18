# Unblur — Architecture Decision Records

> Records the reasoning behind every major technical choice. Prevents re-debating settled decisions and documents trade-offs for future reference.
>
> Format follows the [ADR standard](https://adr.github.io/).

---

## ADR-001: Backend — Supabase

**Status:** Accepted
**Date:** 2026-04-11

**Context:** Need a backend to store transcription/translation data, run server-side functions (Whisper API, LLM API), and serve data to iOS client and Web Admin. Project is personal/small-scale, budget-sensitive, and should minimize ops overhead.

**Decision:** Supabase (free tier)

**Pros:**
- Managed PostgreSQL — mature, portable, standard SQL
- Edge Functions for server-side logic (Deno/TypeScript)
- Built-in Storage for file uploads
- Generous free tier (500MB DB, 1GB storage, 500K function invocations/month)
- No time limit on free tier (unlike AWS free tier which expires after 12 months)
- Swift SDK and JS SDK officially supported
- Data fully exportable via `pg_dump` — low vendor lock-in on the data layer

**Cons:**
- Edge Function timeout: 150s (free) / 400s (Pro) — constrains long audio transcription
- No live chat support, even on Enterprise plan
- Occasional service incidents (dashboard log outage April 2026, India ISP issues Feb 2026)
- Value-added services (Auth, Realtime, Edge Functions) are Supabase-specific — migration requires rewriting those layers

**Alternatives considered:**
- **AWS (RDS + Lambda + S3):** More powerful but significantly more complex to set up and maintain. RDS costs ~$13/month after free tier expires. Overkill for this project's scale.
- **Firebase:** Good for mobile but uses NoSQL (Firestore), which is less suitable for relational data like transcript segments with foreign keys.
- **Self-hosted Postgres + VPS:** Maximum control but requires server maintenance, security patching, backups. Not worth it for a personal project.

**Risks & mitigations:**
- Edge Function 150s timeout for long audio: Whisper API typically processes 30min audio in 30-60s, within limit. For very long episodes (>45min), split audio before sending.
- Supabase outage: iOS app caches downloaded content in SwiftData, playback unaffected. Only sync/transcription/translation blocked temporarily.

---

## ADR-002: Web Admin — Next.js on Vercel

**Status:** Accepted
**Date:** 2026-04-11

**Context:** Need a web-based admin panel for managing episodes, triggering transcription/translation, editing transcripts, and uploading audio.

**Decision:** Next.js (App Router) deployed on Vercel

**Pros:**
- Server-side rendering and API routes in one framework
- Vercel deployment is zero-config for Next.js (same company)
- Free tier sufficient for single-user admin
- Supabase JS SDK integrates naturally
- Large ecosystem, well-documented, AI generates high-quality Next.js code

**Cons:**
- Vercel serverless function timeout: 60s (free) / 300s (Pro) — not suitable for long-running tasks
- CVE-2025-29927: middleware auth bypass vulnerability (mitigated by checking auth in Server Actions, not just middleware)
- Vendor coupling between Next.js and Vercel (deployment is optimized for Vercel; other hosts work but with more setup)

**Alternatives considered:**
- **Plain React SPA + Supabase client:** Simpler, but no server-side capabilities for auth or API key protection.
- **Remix:** Similar capabilities to Next.js but smaller ecosystem and less AI training data.
- **Admin panel generator (Retool, Appsmith):** Fast but limited customization, and adds another vendor dependency.

**Risks & mitigations:**
- Middleware auth bypass: All data operations verify auth in Server Actions / Route Handlers, not just middleware. See VERSION_PLAN §Security.
- Vercel timeout: Long-running tasks (transcription) run on Supabase Edge Functions, not Vercel. Admin only triggers them.

---

## ADR-003: UI Components — shadcn/ui

**Status:** Accepted
**Date:** 2026-04-11

**Context:** Need a component library for the Web Admin that is clean, customizable, and works well with AI-generated code.

**Decision:** shadcn/ui + Tailwind CSS

**Pros:**
- Copy-paste components (not a dependency — code lives in your project)
- Built on Radix UI primitives (accessible, well-tested)
- Tailwind-based styling, easy to customize themes
- Most popular React component library in 2025-2026, excellent AI training data coverage
- Clean, professional look out of the box

**Cons:**
- Requires manual installation of each component (`npx shadcn@latest add button`)
- No built-in layout system (you assemble pages yourself)
- Tailwind learning curve if unfamiliar (minimal for this project)

**Alternatives considered:**
- **Ant Design:** Full-featured but opinionated, heavy bundle size, harder to customize.
- **Material UI:** Google aesthetic, not aligned with our warm/neutral design language.
- **Headless UI + Tailwind:** Maximum flexibility but requires building every component from scratch.

---

## ADR-004: Transcription — OpenAI Whisper API via Edge Function

**Status:** Accepted
**Date:** 2026-04-11

**Context:** Need speech-to-text for podcast episodes with word-level timing. Options: on-device (WhisperKit) vs. cloud API.

**Decision:** OpenAI Whisper API called from Supabase Edge Function

**Pros:**
- Transcribe once on server, all clients get the result (vs. each device running Whisper independently)
- No ~1GB model download on each user's device
- `verbose_json` response format provides word-level timestamps out of the box
- Server-side API key — not exposed to clients
- Consistent quality regardless of device hardware

**Cons:**
- Requires network to transcribe (not a problem — admin triggers transcription, not end users)
- API cost: ~$0.006/minute of audio (~$0.12 per 20-minute episode)
- Dependent on OpenAI API availability
- Edge Function 150s timeout constrains very long episodes

**Alternatives considered:**
- **WhisperKit (on-device):** Original v0.2 plan. Rejected because every device would redundantly transcribe the same episodes, requires large model download, drains battery, and slower on older devices.
- **AssemblyAI / Deepgram:** Similar cloud APIs with word-level timing. OpenAI chosen for familiarity and pricing.
- **Self-hosted Whisper on GPU server:** Best accuracy/cost ratio at scale, but massive ops overhead for a personal project.

**Risks & mitigations:**
- OpenAI API deprecation: Whisper is widely used and unlikely to be removed. If deprecated, AssemblyAI or Deepgram are drop-in alternatives (same Edge Function, different API call).
- Cost at scale: 100 episodes × 20min × $0.006 = ~$12 total. Very manageable.

---

## ADR-005: Audio Storage — Hybrid (CDN + Supabase Storage)

**Status:** Accepted
**Date:** 2026-04-11

**Context:** Need to decide where audio files are stored. RSS podcast audio is already hosted on Megaphone CDN. Future sources (YouTube, manual uploads) won't have a CDN.

**Decision:** Hybrid approach — RSS audio downloaded directly from CDN, manually uploaded audio stored in Supabase Storage.

**Pros:**
- Free for RSS content (CDN is the podcast host's cost, not ours)
- Supabase free tier storage (1GB) preserved for non-RSS uploads only
- No redundant copying of audio that's already hosted
- Scales naturally: RSS episodes cost nothing, uploads scale with Supabase tier

**Cons:**
- Two different audio source paths (CDN URL vs. Supabase Storage signed URL) — slightly more complex download logic
- RSS CDN availability is outside our control (if podcast host goes down, audio unavailable)
- Cannot modify or re-encode RSS audio (it's hosted externally)

**Alternatives considered:**
- **Store everything in Supabase Storage:** Simpler code (one source), but 100+ episodes × ~15MB = ~1.5GB, exceeds free tier immediately. Would require Pro plan ($25/month).
- **Store nothing (always stream from source):** No offline support. Rejected.

---

## ADR-006: iOS E2E Testing — Maestro

**Status:** Accepted
**Date:** 2026-04-11

**Context:** Need E2E testing for iOS app. App UI will grow in complexity over time and won't always use stock SwiftUI components.

**Decision:** Maestro for E2E, XCTest for service-layer unit tests

**Pros:**
- Declarative YAML syntax — significantly less code than XCUITest
- Built-in auto-wait — no manual synchronization, less flaky
- Fast execution, comparable to XCUITest
- Open source, free
- Easy for AI to generate and maintain
- Supports SwiftUI

**Cons:**
- Third-party tool — not guaranteed to keep up with every iOS release immediately
- Smaller community than XCUITest
- Cannot test platform-specific edge cases as deeply as XCUITest
- Requires Maestro CLI installation (not built into Xcode)

**Alternatives considered:**
- **XCUITest:** Apple native, always compatible, but verbose Swift code, manual wait handling, high maintenance cost as UI grows complex.
- **Appium:** Cross-platform but slowest option, most flaky, highest setup complexity.
- **No E2E tests:** Lowest cost but no safety net as UI grows. Rejected given the user's intent to build increasingly complex UI.

---

## ADR-007: iOS Audio File Storage — Application Support Directory

**Status:** Accepted
**Date:** 2026-04-11

**Context:** Downloaded audio files need to be stored locally on the user's device. Files should not be visible to or modifiable by the user through the Files app.

**Decision:** Store in Application Support directory

**Pros:**
- Not visible to users via Files app (unlike Documents directory)
- Not purged by the system (unlike Caches directory)
- Backed up by default (iCloud/iTunes)
- Apple's recommended location for app-managed data files

**Cons:**
- Backed up by default — large audio files increase iCloud backup size. Can mark individual files as excluded from backup if needed.
- Directory not created by default — must create it programmatically on first use

**Alternatives considered:**
- **Documents directory:** User-visible via Files app. User could delete or rename audio files, breaking the app. Rejected.
- **Caches directory:** System may purge when storage is low. Downloaded episodes would disappear unexpectedly. Rejected.
- **tmp directory:** Cleared on app restart. Not suitable for persistent storage. Rejected.

---

## ADR-008: Default AI Models — DeepSeek V3.2

**Status:** Accepted
**Date:** 2026-04-11

**Context:** Need default LLM models for two backend-paid tasks: translation (v0.3) and Q&A fallback (v0.4, for users without their own API key). Priorities: cheap (we pay), good Chinese, adequate reasoning for English learning Q&A. Separate env vars for each role so they can diverge later.

**Decision:** DeepSeek V3.2 for both translation and Q&A fallback

**Pricing:** $0.14/M input, $0.28/M output — among the cheapest available

**Pros:**
- Extremely cheap (~$0.14/$0.28 per million tokens)
- Strong Chinese language capability (native-level, trained on Chinese data)
- Good reasoning ability, surpasses GPT-4 level on many benchmarks
- OpenAI-compatible API format — easy to swap providers later
- 100 episodes × translation ≈ $0.50 total cost

**Cons:**
- Peak-hour latency issues (servers in Asia, capacity constraints during Chinese business hours)
- Less established than OpenAI/Anthropic — potential API stability concerns
- Company is Chinese-based — may have content moderation differences

**Alternatives considered:**
- **GPT-4o Mini ($0.15/$0.60):** Most stable, but Chinese quality is noticeably weaker than Chinese-native models. Good fallback if DeepSeek has issues.
- **Kimi K2.5 ($0.60/$2.50):** Excellent Chinese but 4x more expensive. Not justified for a free fallback tier.
- **Qwen3 (~$0.40/$1.60):** Best Chinese quality, but ~3x more expensive. Better suited for a future paid subscription tier.
- **Gemini 2.0 Flash Lite ($0.075/$0.30):** Cheapest, but Chinese and reasoning quality both weaker.
- **Claude Haiku ($0.80/$4.00):** Good all-around but expensive for a free fallback.
- **Grok 4.1 ($0.20/$0.50):** Chinese language support is weakest among candidates. Not suitable for this use case.

**Future plan:** When subscription is added (v0.5+), upgrade Q&A to a stronger model (Claude Sonnet or similar) for paying users. DeepSeek remains as the free tier fallback.

---

## ADR-009: iOS Image Loading — Nuke

**Status:** Accepted
**Date:** 2026-04-18

**Context:** The episode list (002) renders 60×60pt artwork thumbnails for every row. Initial implementation used SwiftUI's built-in `AsyncImage`, which caused ~700 MB memory use with only 30 episodes loaded and visible scroll stutter. Root cause: `AsyncImage` decodes images at their full source resolution (podcast artwork is typically 1400×1400 or 3000×3000), has no persistent cache, and decodes on the main thread.

**Decision:** Adopt [Nuke](https://github.com/kean/Nuke) via SPM. Use `NukeUI.LazyImage` with `ImageProcessors.Resize` to downsample artwork to 2× the display size (120×120px) before decoding.

**Pros:**
- Built-in downsampling via `ImageProcessors.Resize` — reduces per-image memory by ~100×
- Memory + disk cache with automatic LRU eviction
- Off-main-thread decoding — keeps scrolling at 60fps
- Automatic task cancellation when cells are recycled during fast scrolling
- Concurrent download limiting out of the box
- Swift-first API, `Sendable` / actor-correct under Swift 6 strict concurrency
- `LazyImage` is a drop-in SwiftUI view that mirrors `AsyncImage`'s API
- Actively maintained, ~6k stars, small footprint (~500 KB)

**Cons:**
- Adds a third-party SPM dependency
- One more library to track for security / maintenance (mitigated by Nuke's stable release cadence)

**Alternatives considered:**
- **Hand-rolled image loader (URLSession + CGImageSource downsample + NSCache):** Feasible in ~80-120 LOC, but has many subtle correctness traps — task cancellation on cell recycle, Swift 6 Sendable correctness, concurrent download limiting, decode prioritization. Rebuilding a solved problem violates the project's "Research & Reuse Mandatory" principle.
- **Kingfisher:** Equally capable and more popular (~23k stars), but heavier (~1.5 MB), older API style, and includes GIF/animation features unused here. Nuke is a cleaner fit for SwiftUI + Swift 6.
- **Keep `AsyncImage` and only add caching via `URLCache`:** Solves repeated downloads but not the memory or main-thread decoding problem. Rejected — doesn't address the root cause.

**Risks & mitigations:**
- Dependency abandonment: Nuke has been actively maintained since 2015. If abandoned, swap with Kingfisher is straightforward (both wrap the same SwiftUI + image loading contract). The call sites are isolated to `EpisodeRowView`.
- Cache growth: Nuke's default disk cache cap (150 MB) is well below iOS storage pressure thresholds. Monitor if the app adds other image sources later.
