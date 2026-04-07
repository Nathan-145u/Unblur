# Unblur — Version Plan

> A native podcast-based English learning tool, initially built for The Squiz Today.
> RSS Feed: `https://feeds.megaphone.fm/STHZE1330487576`
>
> **Language rule: All spec documents must be written in English only.**

---

## v0.1 — Listen

- RSS parsing + episode list (title, date, duration)
- Episode title keyword search
- Single episode audio download
- Basic player (play/pause, progress bar, playback speed)
- Resume playback position

## v0.2 — Subtitles

- Auto-transcription on download (WhisperKit, on-device)
- Sentence-level subtitle display + auto-scroll + tap-to-seek
- Word-level highlighting (real-time current word highlight)

## v0.3 — Translation

- Chinese translation (AI API, sentence-by-sentence, bilingual alignment)
- Display mode toggle (English only / bilingual / subtitles off)
- API key management (Keychain storage)

## v0.4 — Polish + advanced features (vibe coding OK)

- Batch download + storage management (delete, disk usage)
- Keyboard shortcuts
- Claude AI Q&A panel (select subtitle text to ask, preset templates)
- Subtitle export (SRT / VTT / TXT / PDF)
- Chat history persistence
- Multi-platform UI refinement

---

## Development strategy

- **Platform:** Build for iOS first; iPad shares the same target for free; macOS adaptation last.
- **Claude Code:** Core learning modules written by hand; Claude Code assists when stuck.
- **v0.1–v0.3 prioritize learning; v0.4 can be vibe-coded.**
