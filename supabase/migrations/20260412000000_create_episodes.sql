-- episodes (v0.1, with v0.2/v0.3 columns pre-created per CONSTITUTION.md deviation)
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

-- episodes view (client-facing read API layer)
create view public.episodes_view as
select id, title, publish_date, duration, remote_audio_url, artwork_url,
       source_type, transcription_status, translation_status
from episodes;

-- RLS: enable on episodes, anon can only SELECT
alter table episodes enable row level security;
create policy "anon_read" on episodes for select using (true);
