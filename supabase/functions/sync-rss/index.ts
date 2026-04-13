import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RSS_FEED_URL = "https://feeds.megaphone.fm/STHZE1330487576";

interface EpisodeRow {
  title: string;
  publish_date: string;
  duration: number;
  remote_audio_url: string;
  artwork_url: string | null;
  source_type: string;
}

function parseDuration(raw: string | null): number {
  if (!raw) return 0;
  const trimmed = raw.trim();

  if (/^\d+$/.test(trimmed)) {
    return parseInt(trimmed, 10);
  }

  const parts = trimmed.split(":").map(Number);
  if (parts.some(isNaN)) return 0;

  if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }
  if (parts.length === 2) {
    return parts[0] * 60 + parts[1];
  }

  return 0;
}

function extractTag(xml: string, tag: string): string | null {
  const regex = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`);
  const match = xml.match(regex);
  return match ? match[1].trim() : null;
}

function extractAttr(xml: string, tag: string, attr: string): string | null {
  const regex = new RegExp(`<${tag}[^>]*${attr}="([^"]*)"`, "i");
  const match = xml.match(regex);
  return match ? match[1] : null;
}

function parseEpisodes(xml: string): EpisodeRow[] {
  // Extract channel-level artwork
  const channelMatch = xml.match(/<channel>([\s\S]*?)<item>/);
  const channelSection = channelMatch ? channelMatch[1] : "";
  const channelArtwork = extractAttr(channelSection, "itunes:image", "href");

  // Split into items
  const itemRegex = /<item>([\s\S]*?)<\/item>/g;
  const episodes: EpisodeRow[] = [];
  let match;

  while ((match = itemRegex.exec(xml)) !== null) {
    const item = match[1];

    const title = extractTag(item, "title");
    const remoteAudioUrl = extractAttr(item, "enclosure", "url");

    if (!title || !remoteAudioUrl) continue;

    const pubDateStr = extractTag(item, "pubDate");
    if (!pubDateStr) continue;
    const pubDate = new Date(pubDateStr);
    if (isNaN(pubDate.getTime())) continue;

    const durationStr = extractTag(item, "itunes:duration");
    const duration = parseDuration(durationStr);

    const artworkUrl = extractAttr(item, "itunes:image", "href") ?? channelArtwork;

    episodes.push({
      title,
      publish_date: pubDate.toISOString(),
      duration,
      remote_audio_url: remoteAudioUrl,
      artwork_url: artworkUrl,
      source_type: "rss",
    });
  }

  return episodes;
}

Deno.serve(async () => {
  // Fetch RSS feed
  let rssText: string;
  try {
    const res = await fetch(RSS_FEED_URL);
    if (!res.ok) {
      return new Response(
        JSON.stringify({ data: null, error: { code: "RSS_FETCH_FAILED", message: `HTTP ${res.status}` } }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }
    rssText = await res.text();
  } catch (e) {
    return new Response(
      JSON.stringify({ data: null, error: { code: "RSS_FETCH_FAILED", message: (e as Error).message } }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  // Parse XML
  let episodes: EpisodeRow[];
  try {
    episodes = parseEpisodes(rssText);
    if (episodes.length === 0) {
      throw new Error("No valid episodes found");
    }
  } catch {
    return new Response(
      JSON.stringify({ data: null, error: { code: "RSS_PARSE_ERROR", message: "Failed to parse RSS XML" } }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // Upsert to database
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Count rows before upsert
  const { count: countBefore } = await supabase
    .from("episodes")
    .select("*", { count: "exact", head: true });

  const { error: upsertError } = await supabase
    .from("episodes")
    .upsert(episodes, { onConflict: "remote_audio_url" });

  if (upsertError) {
    return new Response(
      JSON.stringify({ data: null, error: { code: "RSS_PARSE_ERROR", message: upsertError.message } }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // Count rows after upsert
  const { count: countAfter } = await supabase
    .from("episodes")
    .select("*", { count: "exact", head: true });

  const inserted = (countAfter ?? 0) - (countBefore ?? 0);
  const updated = episodes.length - inserted;

  return new Response(
    JSON.stringify({ data: { inserted, updated, total: episodes.length }, error: null }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
