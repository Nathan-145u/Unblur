# Unblur — Version Plan

> A native podcast-based English learning tool, initially built for The Squiz Today.
>
> **Language rule: All spec documents must be written in English only.**
>
> **All decisions must follow [CONSTITUTION.md](./CONSTITUTION.md).** Deviations require documented justification.
> **Technical choices documented in [DECISIONS.md](./DECISIONS.md)** (Architecture Decision Records).

---

## Architecture

```
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│    iOS App       │       │    Supabase      │       │   Web Admin      │
│    SwiftUI       │◄─────▶│    Backend       │◄─────▶│   Next.js        │
│                  │       │                  │       │   (Vercel)       │
│  - Playback      │       │  - PostgreSQL DB │       │  - Manage audio  │
│  - Subtitles     │       │  - Edge Functions│       │  - Trigger jobs  │
│  - Translation   │       │  - Storage       │       │  - Edit content  │
│  - AI Q&A        │       │  - Auth (future) │       │  - Monitor status│
└──────────────────┘       └──────────────────┘       └──────────────────┘
  iPhone / iPad / Mac
```

### Data Flow

```
RSS Feed (Megaphone CDN)
  │
  ├── Audio ──► iOS client downloads directly from CDN (not stored in Supabase)
  │
  └── Metadata ──► Supabase DB (episode list, synced via RSS parsing)

Supabase Edge Functions:
  ├── transcribe ──► calls OpenAI Whisper API ──► stores segments in DB
  ├── translate  ──► calls LLM API (backend key) ──► stores translations in DB
  └── chat       ──► calls LLM API (user key priority, fallback backend key) ──► streams response

Web Admin (Next.js on Vercel):
  ├── Manages episodes, triggers transcription/translation
  ├── Uploads audio manually (e.g., YouTube rips) ──► Supabase Storage
  └── Edits transcripts, reruns failed jobs

Manually uploaded audio ──► Supabase Storage (hybrid: only non-RSS audio stored here)
```

### API Key Strategy

| Function | Key Source | Rationale |
|----------|-----------|-----------|
| Transcription (Whisper) | Backend key | One-time per episode, predictable cost |
| Translation (LLM) | Backend key | One-time per episode, predictable cost |
| AI Q&A (Chat) | User key priority → fallback backend key | Variable per-user usage, cost shifted to user |

---

## Platforms

- **iPhone**: Primary reference layout
- **iPad**: Shared iOS target; v0.4 adds two-column layout (episode list + player)
- **Mac**: Shared iOS target; v0.4 adds sidebar navigation + keyboard shortcuts

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| iOS App | SwiftUI, SwiftData, AVPlayer, iOS 17+ / iPadOS 17+ / macOS 14+ |
| Backend DB | Supabase (PostgreSQL) |
| Backend Storage | Supabase Storage (manual uploads only) |
| Backend Functions | Supabase Edge Functions (Deno/TypeScript) |
| Transcription | OpenAI Whisper API (via Edge Function) |
| Translation | Configurable LLM (Claude / OpenAI / custom, via Edge Function) |
| AI Q&A | Same LLM provider (via Edge Function) |
| Web Admin | Next.js + shadcn/ui + Tailwind CSS (deployed on Vercel) |
| Auth | None for v0.1–v0.4 (single-user admin) |

---

## Design Language

See [DESIGN.md](./DESIGN.md) for color palette, typography, component specs, and platform-specific guidelines.

---

## Data Access Pattern

### Overview

```
iOS App ──[Supabase Swift SDK, anon key]──► DB (read-only)
iOS App ──[POST + anon key header]────────► Edge Functions (sync-rss, chat)

Admin   ──[Supabase JS SDK, service_role]─► DB (full CRUD)
Admin   ──[POST + service_role header]────► Edge Functions (transcribe, translate)
Admin   ──[Supabase Storage SDK]──────────► Storage (upload/delete audio)
```

### Rules

| Operation Type | Method | Examples |
|---------------|--------|---------|
| **Read data** | Supabase SDK via **Views** (not tables directly) | Fetch episodes, fetch segments, fetch chat history |
| **Write via external API** | Edge Function | Transcribe (Whisper), translate (LLM), chat (LLM), sync RSS |
| **Simple CRUD write** | Supabase SDK (Admin only, service_role) | Edit transcript text, delete episode, update metadata |
| **File upload/delete** | Supabase Storage SDK (Admin only) | Upload audio, delete uploaded audio |

### Database Views (read API layer)

Clients read from Views, not tables directly. This decouples the client from the database schema. See [SCHEMA.md](./SCHEMA.md) §Views for the full View definitions and §RLS Policies for access control.

### Authentication for Edge Functions

Edge Functions are called with standard Supabase auth headers:
- iOS: `Authorization: Bearer <SUPABASE_ANON_KEY>`
- Admin: `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`

Edge Functions internally use `service_role` to write to the database (bypasses RLS).

### Pagination

Episode list uses cursor-based pagination:
- **Page size:** 30 episodes per request
- **Sort:** `publish_date DESC, id DESC`
- **Cursor:** Composite `(publish_date, id)` of last item in current page — guarantees unique ordering even when multiple episodes share the same timestamp
- **First page:** `select * from episodes_view order by publish_date desc, id desc limit 30`
- **Next pages:** `select * from episodes_view where (publish_date, id) < (:cursor_date, :cursor_id) order by publish_date desc, id desc limit 30`
- **iOS:** Infinite scroll — load next page when user scrolls near bottom
- **Admin:** Table pagination with page controls

Transcript segments and chat messages are NOT paginated (loaded in full per episode — typically <200 segments, <100 messages).

---

## Edge Function API Contract

### Response Envelope (all non-streaming functions)

**Success (200):**
```json
{ "data": { ... }, "error": null }
```

**Error (4xx/5xx):**
```json
{ "data": null, "error": { "code": "ERROR_CODE", "message": "Human-readable description" } }
```

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 400 | Client error (missing params, precondition not met) |
| 401 | Authentication failed (invalid user API key) |
| 404 | Resource not found |
| 409 | Conflict (already processing) |
| 502 | Upstream API failure (Whisper / LLM) |
| 504 | Upstream timeout |

### Per-Function Contract

| Function | Method | Success `data` | Error Codes |
|----------|--------|----------------|-------------|
| `sync-rss` | POST | `{ inserted, updated, total }` | `RSS_FETCH_FAILED` (502), `RSS_PARSE_ERROR` (500) |
| `transcribe` | POST `{ episode_id }` | `{ episode_id, segment_count }` | `EPISODE_NOT_FOUND` (404), `ALREADY_TRANSCRIBING` (409), `WHISPER_API_ERROR` (502), `TIMEOUT` (504) |
| `translate` | POST `{ episode_id }` | `{ episode_id, translated_count }` | `EPISODE_NOT_FOUND` (404), `NOT_TRANSCRIBED` (400), `ALREADY_TRANSLATING` (409), `LLM_API_ERROR` (502) |
| `chat` | POST `{ episode_id, message, selected_text, history[], user_api_key?, user_provider?, user_model? }` | SSE stream (see below) | `EPISODE_NOT_FOUND` (404), `NO_TRANSCRIPT` (400), `INVALID_API_KEY` (401), `LLM_API_ERROR` (502) |

### Chat Streaming Format (SSE)

- Content type: `text/event-stream`
- Token chunk: `data: {"token": "word"}\n\n`
- Completion: `data: {"done": true}\n\n`
- Pre-stream error: standard JSON error response (not SSE)
- Mid-stream error: `data: {"error": {"code": "STREAM_INTERRUPTED", "message": "..."}}\n\n`

---

## Data Model

See [SCHEMA.md](./SCHEMA.md) for all database tables, Views, RLS policies, and SQL DDL. SCHEMA.md is the single source of truth for all database schema.

---

## Version Overview

| Version | Theme | Features |
|---------|-------|----------|
| v0.1 | Listen | ~~001-rss-sync~~, 002-episode-list, 003-audio-download, 004-audio-player |
| v0.2 | Subtitles | 001-transcribe, 002-subtitle-display, 003-admin-transcription, 004-force-upgrade |
| v0.3 | Translation | 001-translate, 002-bilingual-display, 003-admin-translation |
| v0.4 | Polish + AI | 001-batch-download, 002-storage-management, 003-ai-qa, 004-admin-full, 005-multiplatform |

Feature specs: `specs/v{version}/{feature}/spec.md`

---

## Supabase Free Tier Budget

| Resource | Estimated Usage | Free Tier Limit |
|----------|----------------|-----------------|
| Database | ~10MB (transcripts + translations + metadata) | 500MB |
| Storage | 0 initially (RSS audio from CDN) | 1GB |
| Edge Functions | Low frequency (transcribe/translate triggers) | 500K invocations/month |
| Bandwidth | Transcripts + translations download | 5GB/month |

---

## Security

### Row Level Security (RLS)

See [SCHEMA.md](./SCHEMA.md) §RLS Policies for full SQL. Summary: RLS enabled on all tables, `anon` can SELECT only, writes via `service_role` (bypasses RLS).

### Web Admin Authentication

Next.js middleware alone is NOT safe for auth (CVE-2025-29927: middleware can be bypassed via `x-middleware-subrequest` header). Defense-in-depth approach:

1. **Login page:** User enters password → verified against `ADMIN_PASSWORD` env var → server sets httpOnly cookie
2. **Every Server Action / Route Handler:** Checks the cookie before executing. This is the real security layer.
3. **Middleware:** Redirects unauthenticated users to login page (UX convenience, not security boundary)

This ensures that even if middleware is bypassed, no data operation can execute without valid authentication.

### CORS (Edge Functions)

CORS is a browser-enforced policy. It only affects the Web Admin (browser JS). iOS native HTTP requests are not subject to CORS.

**Configuration:**
- Shared CORS headers in `supabase/functions/_shared/cors.ts`
- Every Edge Function handles `OPTIONS` preflight requests
- `Access-Control-Allow-Origin` set to the Admin's Vercel domain (not `*`)
- iOS client is unaffected

```typescript
// supabase/functions/_shared/cors.ts
export const corsHeaders = {
  "Access-Control-Allow-Origin": "https://admin.unblur.app",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};
```

---

## Environment Variables

> Naming convention: role-based names for variables we define; platform/SDK convention names kept as-is (see [CONSTITUTION.md](./CONSTITUTION.md)).

### Supabase Edge Functions

| Variable | Purpose | Version | Notes |
|----------|---------|---------|-------|
| `SUPABASE_URL` | Supabase project URL | v0.1 | Auto-provided by platform |
| `SUPABASE_ANON_KEY` | Public read key | v0.1 | Auto-provided by platform |
| `SUPABASE_SERVICE_ROLE_KEY` | Write access (bypasses RLS) | v0.1 | Auto-provided by platform |
| `TRANSCRIPTION_API_KEY` | OpenAI Whisper API key | v0.2 | Role-based name |
| `TRANSLATION_PROVIDER` | `deepseek` / `openai` / `claude` / `custom` | v0.2 | Role-based name. Default: `deepseek`. Used for sentence segmentation (v0.2) and translation (v0.3). |
| `TRANSLATION_API_KEY` | API key for LLM (segmentation + translation) | v0.2 | Role-based name |
| `TRANSLATION_MODEL` | Model name | v0.2 | Role-based name. Default: `deepseek-v3` |
| `TRANSLATION_BASE_URL` | Endpoint URL | v0.2 | Default: `https://api.deepseek.com` |
| `QA_PROVIDER` | `deepseek` / `openai` / `claude` / `custom` | v0.4 | Role-based name. Default: `deepseek` |
| `QA_API_KEY` | API key for Q&A fallback | v0.4 | Role-based name |
| `QA_MODEL` | Model name | v0.4 | Role-based name. Default: `deepseek-v3` |
| `QA_BASE_URL` | Endpoint URL | v0.4 | Default: `https://api.deepseek.com` |

### Vercel (Web Admin)

| Variable | Purpose | Version | Notes |
|----------|---------|---------|-------|
| `NEXT_PUBLIC_SUPABASE_URL` | Client-side Supabase connection | v0.2 | Next.js SDK convention (`NEXT_PUBLIC_` prefix required) |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Client-side read access | v0.2 | Next.js SDK convention |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side write access | v0.2 | SDK convention |
| `ADMIN_PASSWORD` | Admin login password | v0.2 | Role-based name |

### iOS App (Xcode Build Configuration)

| Variable | Purpose | Version | Notes |
|----------|---------|---------|-------|
| `SUPABASE_URL` | Supabase project URL | v0.1 | Swift SDK convention |
| `SUPABASE_ANON_KEY` | Read access | v0.1 | Swift SDK convention |

> iOS values stored in Xcode build configuration or `Info.plist`, never hardcoded in source code.

---

## Repository Structure

Monorepo — all three components in one repository:

```
Unblur/
├── CLAUDE.md                      # SDD trampoline (references CONSTITUTION.md)
├── docs/                          # Layer 1: Project-level documents
│   ├── CONSTITUTION.md            # Principles, constraints, deviations log
│   ├── DECISIONS.md               # Architecture Decision Records
│   ├── SCHEMA.md                  # Database schema (SSOT)
│   ├── DESIGN.md                  # Design language tokens
│   └── VERSION_PLAN.md            # Roadmap & version overview (this file)
├── specs/                         # Layer 2+3: Feature specs + execution tasks
│   ├── v0.1/
│   │   ├── 001-rss-sync/
│   │   │   └── spec.md
│   │   ├── 002-episode-list/
│   │   │   └── spec.md
│   │   ├── 003-audio-download/
│   │   │   └── spec.md
│   │   └── 004-audio-player/
│   │       └── spec.md
│   ├── v0.2/
│   ├── v0.3/
│   └── v0.4/
├── ios/                           # iOS App (SwiftUI)
│   ├── Unblur.xcodeproj
│   └── Unblur/
│       ├── UnblurApp.swift
│       ├── Models/
│       ├── Services/
│       ├── Views/
│       └── Utilities/
├── admin/                         # Web Admin (Next.js + shadcn/ui)
│   ├── package.json
│   ├── app/
│   ├── components/
│   └── lib/
├── supabase/                      # Supabase configuration
│   ├── config.toml
│   ├── migrations/                # SQL migration files (versioned)
│   └── functions/                 # Edge Functions
│       ├── _shared/
│       │   └── cors.ts
│       ├── sync-rss/
│       │   └── index.ts
│       ├── transcribe/
│       │   └── index.ts
│       ├── translate/
│       │   └── index.ts
│       └── chat/
│           └── index.ts
├── .gitignore
└── README.md
```

**Rationale:** Three components are tightly coupled (shared data model, API contract). Monorepo allows a single PR to update Edge Function + client code together. Project scale does not warrant separate repositories.

> **Migration note:** The existing iOS project at repository root (`Unblur/`) must be moved to `ios/` subdirectory before v0.1 implementation begins.

---

## Offline Behavior

| Scenario | Behavior |
|----------|----------|
| Offline + has downloaded episodes | List shows only downloaded episodes (from SwiftData). Playback works normally. Subtitles display from local cache (if previously fetched). |
| Offline + no downloaded episodes | Full-screen message: "No internet connection." |
| Offline + open Full Player | Playback works. Subtitles show cached segments. If no cached segments: "No subtitles available." |
| Offline + tap undowned episode | N/A — undownloaded episodes not shown offline |
| Offline + AI Q&A | "Network required for AI Q&A." |
| Network restored | Pull-to-refresh fetches full list from Supabase. No automatic retry. |
| Orphaned local files | If an episode exists in SwiftData but not in Supabase fetch result (deleted by admin), keep local file playable but do not show in the online list. Local-only episodes visible offline only. User can delete via Settings storage management (v0.4). |
| Offline + bilingual subtitles (v0.3+) | Translation text cached in SwiftData alongside segments. Available offline for downloaded episodes. |
| Offline + AI Q&A (v0.4) | "Network required for AI Q&A." Chat history not loaded offline. |

### Local Storage

**Audio files:** Stored in `Application Support` directory (not Documents). Users cannot see, modify, or delete audio files via the Files app.

**SwiftData model (`LocalEpisode`):** Caches episode metadata at download time so downloaded episodes can be displayed offline.

```swift
@Model
class LocalEpisode {
    var episodeId: UUID
    var title: String              // cached at download time
    var publishDate: Date          // cached at download time
    var duration: Int              // cached at download time
    var artworkURL: String?        // cached at download time
    var remoteAudioURL: String     // cached at download time
    var localAudioFilename: String?
    var lastPlayPosition: Double   // seconds
}
```

**Download progress** is a runtime-only property on `DownloadManager` (`@Observable`), NOT persisted to SwiftData. If the app is killed during download, the incomplete file is discarded.

**Transcript segments:** Cached in SwiftData after first fetch from Supabase (v0.2). Available offline for downloaded episodes.

---

## Testing Strategy

### Principle

Cover all critical paths — flows where breakage would destroy the user's core experience. No fixed test count; scope scales with each version's feature set.

### iOS App

| Layer | Tool | What to Test |
|-------|------|-------------|
| Service logic | XCTest | RSS parsing, download state machine, playback management, data merging |
| E2E critical flows | Maestro (YAML) | Core user journeys — scope determined per version based on acceptance criteria |

Maestro tests written in declarative YAML. Lower maintenance than XCUITest, built-in auto-wait, no manual synchronization needed.

### Web Admin

| Layer | Tool | What to Test |
|-------|------|-------------|
| E2E critical flows | Playwright | Core admin operations — scope determined per version based on acceptance criteria |

### Edge Functions

| Layer | Tool | What to Test |
|-------|------|-------------|
| Integration | Supabase CLI (`supabase functions serve`) + HTTP requests | Happy path + primary error path per function |

### What Counts as a Critical Path

A critical path is any flow where breakage means **the user's core experience is broken**. Examples:
- v0.1: "Download an episode and play it" — if this breaks, the app is useless
- v0.2: "Play episode with subtitles scrolling" — core v0.2 value proposition
- v0.4: "Ask AI about a subtitle segment" — core v0.4 feature

Each version's spec defines its own critical paths in the acceptance criteria section.

---

## Development Strategy

- **Approach:** Fully spec-driven (vibe coding). Each version has a self-contained spec with data models, UI behavior, state machines, error handling, and acceptance criteria.
- **Order:** Build each version sequentially. Each version's acceptance criteria must pass before moving to the next.
- **RSS Feed (v0.1–v0.4):** `https://feeds.megaphone.fm/STHZE1330487576` (hardcoded, but architecture supports future multi-source)
