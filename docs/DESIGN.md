# Unblur — Design Language

> Inspired by warm, modern UI with soft tones and organic accents.
> Reference: Glassmorphism + warm neutral palette with orange accent.

---

## Color Palette

| Token | iOS (SwiftUI) | Web (Tailwind) | Usage |
|-------|---------------|----------------|-------|
| Background | `.background` (system) | `bg-stone-50` (#fafaf9) | Page/screen background |
| Surface | cream/warm white | `bg-orange-50` (#fff7ed) | Cards, list rows, player |
| Accent | custom orange `#F28C38` | `orange-500` (#f97316) | Buttons, highlights, current subtitle, progress bars |
| Text Primary | `.primary` | `stone-900` | Titles, body text |
| Text Secondary | `.secondary` | `stone-500` | Dates, durations, metadata |
| CTA / Contrast | black | `stone-900` | Primary action buttons |

---

## iOS App

- **Style:** Stock Apple + warm color palette + orange accent
- **Components:** Native SwiftUI (`List`, `NavigationStack`, `.sheet`, `.toolbar`)
- **Typography:** SF Pro (system default)
- **Accent color:** Custom orange (`#F28C38`) set via `.tint()` at app root
- **Icons:** SF Symbols
- **Cards:** Large corner radius (16pt) where applicable (full player, mini player)
- **Principle:** Apple HIG as foundation, warmed up with the accent palette. No custom design work beyond color tokens.

---

## Web Admin

- **Style:** shadcn/ui + Tailwind CSS, warm neutral theme
- **Typography:** Inter (shadcn default)
- **Colors:** Override shadcn theme: `--primary: orange-500`, `--background: stone-50`, `--card: orange-50`
- **Components:** Pre-built shadcn components (`Table`, `Button`, `Dialog`, `Card`, `Badge`, `Sheet`)
- **Principle:** Functional and clean. Warm tone consistent with iOS app.
