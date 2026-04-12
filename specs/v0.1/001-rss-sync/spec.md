# Spec — RSS Sync

## 1. Scope

**Included:**
- Supabase Edge Function `sync-rss`: fetch and parse episode metadata from a hardcoded RSS feed, upsert into the `episodes` table
- SQL migration: create `episodes` table, `episodes_view`, RLS policies, indexes (per [SCHEMA.md](../../../docs/SCHEMA.md))
- CORS handling deferred to v0.2 (v0.1 only has iOS callers, not subject to CORS)

**Excluded:**
- iOS or Web Admin calling logic (see 002-episode-list, v0.2 003-admin-transcription)
- Audio file download or storage (see 003-audio-download)
- Manual audio upload (v0.4)
- Multiple RSS source support (v0.5+)

## 2. Technical Context & Constraints

- **Runtime:** Supabase Edge Function (Deno/TypeScript)
- **RSS Feed:** `https://feeds.megaphone.fm/STHZE1330487576` (hardcoded)
- **Database:** See [SCHEMA.md](../../../docs/SCHEMA.md) — `episodes` table, `episodes_view`, RLS policies
- **API contract:** See [VERSION_PLAN.md](../../../docs/VERSION_PLAN.md) §Edge Function API Contract
- **Auth:** Edge Function uses `service_role` key internally to write to the database
- **Prerequisite features:** None (first feature)

## 3. Functional Requirements

### 3.1 Sync Flow

1. Receive a POST request (no body parameters required)
2. Fetch the RSS feed and parse the XML
3. Extract the following data from each episode item:
   - **Title** (from `<title>`)
   - **Publish date** (from `<pubDate>`)
   - **Duration** in seconds (from `<itunes:duration>`, supporting `HH:MM:SS`, `MM:SS`, and raw seconds formats)
   - **Audio URL** (from `<enclosure url="...">`)
   - **Artwork URL** (from `<itunes:image>`; episode-level takes priority, falls back to channel-level)
4. Upsert episodes into the database using audio URL as the dedup key:
   - **New episode:** insert all fields
   - **Existing episode:** update metadata (title, publish date, duration, artwork) only; preserve existing statuses and timestamps
5. Return counts: `{ inserted, updated, total }`

### 3.2 Idempotency

- Multiple syncs of the same feed produce identical database state
- No duplicate rows — guaranteed by the unique constraint on audio URL

## 4. Error Handling Table

| Scenario | HTTP Status | Error Code | Behavior |
|---|---|---|---|
| RSS feed unreachable (network error, non-200 response) | 502 | `RSS_FETCH_FAILED` | Return error, no database changes |
| RSS XML is malformed / unparseable | 500 | `RSS_PARSE_ERROR` | Return error, no database changes |
| Individual episode missing required fields (title or audio URL) | — | — | Skip that episode, continue processing others |
| Duration missing or unparseable | — | — | Default to 0 |
| Publish date missing or unparseable | — | — | Skip that episode (publish_date is NOT NULL) |
| Artwork URL missing | — | — | Set to null |
| Database upsert failure | 500 | `RSS_PARSE_ERROR` | Return error; previously upserted rows in this batch are retained |

## 5. Acceptance Criteria

- [ ] POST `sync-rss` returns `{ data: { inserted, updated, total }, error: null }` on success
- [ ] After first sync, episode count in database matches valid episodes in the RSS feed
- [ ] Repeated sync produces no duplicates; `inserted = 0`
- [ ] If an episode title changes in the RSS feed, re-syncing updates it in the database
- [ ] Unreachable RSS feed returns 502 + `RSS_FETCH_FAILED`
- [ ] Malformed XML returns 500 + `RSS_PARSE_ERROR`
- [ ] Episodes missing title or audio URL are skipped; others are inserted normally
- [ ] Duration correctly parsed from `HH:MM:SS`, `MM:SS`, and raw seconds
- [ ] RLS enforced: `anon` key can only SELECT, not INSERT/UPDATE/DELETE


## 6. Critical Path

1. Deploy SQL migration (episodes table + view + RLS)
2. Deploy `sync-rss` Edge Function
3. POST to `sync-rss` → verify response: `{ inserted: N, updated: 0, total: N }`
4. Query `episodes_view` → confirm N episodes returned
5. POST again → verify: `{ inserted: 0, updated: N, total: N }`, no duplicate rows
