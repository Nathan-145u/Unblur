# Unblur — Project Constitution

> **Layer 1 — always loaded.** Global constraints and principles for this project.
>
> Global engineering rules apply automatically from `~/.claude/rules/common/`.
> This file defines Unblur-specific additions.

---

## Principles

### Offline-Friendly

- Downloaded audio is always playable offline.
- Episode list shows downloaded episodes from SwiftData when offline; no blank screen.
- Features that require network (sync, transcription status, chat) degrade gracefully with clear messaging.
- Network-dependent UI shows loading/error states, never hangs silently.

### SSOT Mapping

| What | Where |
|------|-------|
| Database schema | `docs/SCHEMA.md` |
| Design tokens | `docs/DESIGN.md` |
| Architecture decisions | `docs/DECISIONS.md` |
| Feature behavior | `specs/v0.x/xxx-feature/spec.md` |
| Roadmap & shared context | `docs/VERSION_PLAN.md` |
| API keys | Supabase Secrets / Vercel env vars (server), Keychain (iOS). Never in source code, logs, or UserDefaults. |

---

## Deviations Log

When a decision intentionally deviates from best practice, document it here:

| Decision | Best Practice | What We Did | Reason |
|----------|--------------|-------------|--------|
| v0.1 creates v0.2+ columns | Only create what you need now | Pre-create `transcription_status` etc. | Avoids schema migration complexity for a small project. Columns have defaults and are unused until needed. |
| Supabase/SDK env var names | Role-based naming (`API_URL`) | Keep `SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_URL`, etc. | Platform auto-injects these (Edge Functions) or SDK docs use them as convention. Renaming adds mapping code with no benefit. |
| No independent API layer for reads | Dedicated API server/layer | Supabase SDK reads via Views + Edge Functions for writes | Project scale too small to justify the overhead. Views decouple schema from clients. Migrate reads to Edge Functions when business logic is needed (e.g., subscription gating). |
