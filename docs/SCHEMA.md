# Unblur — Database Schema

> **Single source of truth for all database schema.** Version specs and VERSION_PLAN reference this file — do NOT duplicate schema elsewhere.
> When schema changes are needed during implementation, update THIS file first, then update code.

---

## Tables

### episodes

| Column | Type | Description | Version |
|--------|------|-------------|---------|
| id | uuid (PK) | Primary key | v0.1 |
| title | text | Episode title (from RSS) | v0.1 |
| publish_date | timestamptz | Publish date (from RSS) | v0.1 |
| duration | integer | Audio duration in seconds (from RSS) | v0.1 |
| remote_audio_url | text (unique) | Remote audio URL (from RSS `<enclosure>`) | v0.1 |
| artwork_url | text | Episode or channel artwork URL | v0.1 |
| source_type | text | `rss` or `upload` | v0.1 |
| storage_path | text | Supabase Storage path (only for `upload` type, format: `audio/{episode_id}.{ext}`) | v0.1 |
| transcription_status | text | `none` / `transcribing` / `completed` / `failed` (default: `none`) | v0.2 |
| transcription_error | text | Error message if failed (default: null) | v0.2 |
| translation_status | text | `none` / `translating` / `completed` / `failed` (default: `none`) | v0.3 |
| translation_error | text | Error message if failed (default: null) | v0.3 |
| created_at | timestamptz | Row creation timestamp | v0.1 |
| updated_at | timestamptz | Row update timestamp | v0.1 |

### transcript_segments (v0.2)

| Column | Type | Description |
|--------|------|-------------|
| id | uuid (PK) | Primary key |
| episode_id | uuid (FK → episodes, ON DELETE CASCADE) | Parent episode |
| index | integer | Sort order within episode |
| start_time | float | Segment start time (seconds) |
| end_time | float | Segment end time (seconds) |
| text | text | English transcription |
| words | jsonb | Word-level timing: `[{"word": "string", "start_time": float, "end_time": float}]` |
| translated_text | text | Chinese translation (v0.3, default: null) |
| created_at | timestamptz | Row creation timestamp |

### app_config (v0.2)

| Column | Type | Description |
|--------|------|-------------|
| key | text (PK) | Config key (e.g., `min_app_version`) |
| value | jsonb | Config value |

General-purpose key-value config table. Used for force upgrade (`min_app_version`), and can store other app-wide settings in the future.

---

## Views (read API layer)

Clients read from Views, not tables directly. This decouples the client from the database schema — table columns can be renamed or restructured without breaking clients, as long as the View output stays the same.

```sql
-- v0.1: episodes view (client-facing fields only)
create view public.episodes_view as
select id, title, publish_date, duration, remote_audio_url, artwork_url,
       source_type, transcription_status, translation_status
from episodes;

-- v0.2: transcript segments view
create view public.segments_view as
select id, episode_id, index, start_time, end_time, text, words, translated_text
from transcript_segments;
```

---

## RLS Policies

Enable RLS on all tables. iOS client uses `anon` key (read-only via Views). Edge Functions and Admin use `service_role` key (full access, bypasses RLS).

```sql
alter table episodes enable row level security;
create policy "anon_read" on episodes for select using (true);

alter table transcript_segments enable row level security;
create policy "anon_read" on transcript_segments for select using (true);

alter table app_config enable row level security;
create policy "anon_read" on app_config for select using (true);
```

---

## SQL DDL (canonical)

```sql
-- episodes (v0.1, with v0.2/v0.3 columns pre-created)
create table episodes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  publish_date timestamptz not null,
  duration integer not null default 0,
  remote_audio_url text not null unique,
  artwork_url text,
  source_type text not null default 'rss',
  storage_path text,
  transcription_status text not null default 'none',
  transcription_error text,
  translation_status text not null default 'none',
  translation_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_episodes_publish_date on episodes (publish_date desc);
create index idx_episodes_remote_audio_url on episodes (remote_audio_url);

-- transcript_segments (v0.2)
create table transcript_segments (
  id uuid primary key default gen_random_uuid(),
  episode_id uuid not null references episodes(id) on delete cascade,
  index integer not null,
  start_time float not null,
  end_time float not null,
  text text not null,
  words jsonb not null default '[]',
  translated_text text,
  created_at timestamptz not null default now()
);
create index idx_segments_episode on transcript_segments (episode_id, index);

-- app_config (v0.2)
create table app_config (
  key text primary key,
  value jsonb not null
);
insert into app_config (key, value) values ('min_app_version', '"1.0.0"');
```

---

## iOS Local Data (SwiftData)

Not in Supabase. Local-only state on each device.

See VERSION_PLAN §Offline Behavior for the full `LocalEpisode` model and caching strategy.

---

## Notes

- **Chat messages** are NOT persisted to database. Chat is in-memory only on iOS. See `specs/v0.4/003-ai-qa/spec.md`.
- **v0.2+ columns pre-created in v0.1** (transcription_status, translation_status, etc.) — see CONSTITUTION.md §Deviations Log for rationale.
