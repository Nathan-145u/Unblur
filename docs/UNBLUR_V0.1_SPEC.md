# Unblur v0.1 — Technical Spec

> **Version:** v0.1 (Listen)
> **Platform:** iOS 17+ / iPadOS 17+ / macOS 14+ (iOS-first development)
> **UI Framework:** SwiftUI
> **Persistence:** SwiftData
> **RSS Feed:** `https://feeds.megaphone.fm/STHZE1330487576`
>
> **Language rule: All spec documents must be written in English only.**

---

## 1. Scope

| Feature | Included |
|---------|----------|
| RSS parsing + episode list | Yes |
| Episode title keyword search | Yes |
| Single episode download | Yes |
| Basic audio player | Yes |
| Playback speed control | Yes |
| Resume playback position | Yes |
| Subtitles / transcription | No (v0.2) |
| Translation | No (v0.3) |
| AI Q&A | No (v0.4) |

---

## 2. UI Structure

### 2.1 Episode list (main screen)

- Navigation title: "Unblur"
- Top search bar: filter episodes by title keyword
- Each row displays:
  - Episode title
  - Publish date
  - Duration
  - Download status indicator (not downloaded / downloading / downloaded)
- List sorted by publish date, newest first
- Tap a downloaded episode → start playback
- Tap an undownloaded episode → trigger download
- Auto-refresh RSS on app launch

### 2.2 Mini player bar (bottom)

- Persistent bar at bottom of screen; visible only when an episode is active
- Displays:
  - Episode title (single line, truncated)
  - Thin progress bar
  - Play/pause button
- Tap the mini bar → expand to full player

### 2.3 Full player screen

- Presented as a sheet / full-screen cover from the bottom
- Displays:
  - Episode artwork (from RSS channel artwork)
  - Episode title
  - Publish date
  - Seekable progress bar (draggable)
  - Current time / total duration
  - Playback controls: skip back 15s, play/pause, skip forward 15s
  - Speed selector (0.5x / 0.75x / 1.0x / 1.25x / 1.5x / 2.0x)
- Swipe down to dismiss, returns to episode list

---

## 3. Data Model (SwiftData)

### Episode

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Local unique identifier |
| title | String | Episode title (from RSS) |
| publishDate | Date | Publish date (from RSS) |
| duration | TimeInterval | Audio duration in seconds (from RSS) |
| remoteAudioURL | String | Remote audio URL (from RSS `<enclosure>`) |
| artworkURL | String? | Episode or channel artwork URL |
| localAudioFilename | String? | Local filename after download (nil = not downloaded) |
| downloadProgress | Double | Download progress (0.0 – 1.0) |
| lastPlayPosition | TimeInterval | Last playback position in seconds |

**Computed properties:**
- `isDownloaded: Bool` → `localAudioFilename != nil`
- `localAudioURL: URL?` → Constructed from `localAudioFilename` + app Documents directory

---

## 4. Core Logic

### 4.1 RSS Parsing

- Use `XMLParser` to parse the RSS feed
- Extract fields: `<title>`, `<pubDate>`, `<enclosure url="..." length="..." type="...">`, `<itunes:duration>`, `<itunes:image>`
- Deduplicate against existing SwiftData episodes (match by `remoteAudioURL`)
- Insert new episodes; never overwrite local data (download state, play position, etc.)

### 4.2 Audio Download

- Use `URLSession` to download audio files to the app's Documents directory
- Update `downloadProgress` during download
- Write filename to `localAudioFilename` on completion
- Allow only one download at a time (v0.1 simplification)
- Show error alert on failure; allow retry

### 4.3 Audio Playback

- Use `AVPlayer` to play local audio files
- Playback state managed by an `@Observable` AudioPlayerManager:
  - `currentEpisode: Episode?`
  - `isPlaying: Bool`
  - `currentTime: TimeInterval`
  - `duration: TimeInterval`
  - `playbackRate: Float`
- Supported actions:
  - Play / pause
  - Seek to specific time (drag progress bar)
  - Skip forward / backward 15 seconds
  - Change playback speed
- Save `lastPlayPosition` when switching episodes
- Restore from `lastPlayPosition` when opening a previously played episode
- Save play position when app moves to background
- Save play position on app termination via `scenePhase`

### 4.4 Search

- Local search over cached SwiftData episodes
- Case-insensitive substring match on title (`contains[cd]`)
- Empty search field shows the full list

---

## 5. Project Structure

```
Unblur/
├── UnblurApp.swift              # App entry point
├── Models/
│   └── Episode.swift            # SwiftData model
├── Services/
│   ├── RSSParser.swift          # RSS XML parser
│   ├── DownloadManager.swift    # Audio download manager
│   └── AudioPlayerManager.swift # Audio playback manager
├── Views/
│   ├── EpisodeListView.swift    # Episode list screen
│   ├── EpisodeRowView.swift     # List row component
│   ├── MiniPlayerView.swift     # Bottom mini player bar
│   └── FullPlayerView.swift     # Full-screen player
└── Utilities/
    └── DateFormatter+Ext.swift  # Date formatting helpers
```

---

## 6. Milestones

### M1: Project skeleton + RSS parsing + episode list
- Initialize Xcode project (iOS + macOS targets)
- Configure SwiftData + Episode model
- Implement RSS parser
- Build episode list UI + search
- Auto-fetch RSS on launch

### M2: Audio download
- Implement DownloadManager
- Download progress UI
- Local file management
- Persist download state

### M3: Audio player
- Implement AudioPlayerManager
- Mini player bar UI
- Full player screen UI
- Playback controls (play/pause, skip, speed)
- Resume playback position

---

## 7. Explicitly excluded from v0.1

- Batch download
- Background download (v0.1 supports foreground download only)
- Subtitles / transcription
- Translation
- AI Q&A
- Subtitle export
- Keyboard shortcuts
- macOS / iPad-specific UI optimization (v0.1 uses default iOS layout; other platforms just need to run)
