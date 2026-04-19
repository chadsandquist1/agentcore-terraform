# Handoff: Receipt Classifier POC

## Overview
A simple, single-page web app that lets a user drop in a receipt image and see it classified. Each classification returns **two attributes**:
1. **Category** — one of: Groceries, Dining, Transport, Utilities, Retail.
2. **Description** — a short natural-language sentence summarizing the receipt.

A "Recent" list below the dropzone shows previously classified receipts. This is a POC — the classifier itself is stubbed.

## About the Design Files
The files in this bundle are **design references created in HTML** — a working prototype showing the intended look and behavior, not production code to copy directly. The task is to **recreate this HTML design in the target codebase's existing environment** (React, Next.js, Vue, SvelteKit, etc.) using its established patterns and libraries. If no codebase exists yet, choose the most appropriate framework (Next.js + Tailwind is a sensible default for this kind of POC) and implement the design there.

The classification logic in the prototype is a `setTimeout` + random pick — replace it with a real backend call (e.g. an API route that forwards the image to a vision model).

## Fidelity
**High-fidelity.** The prototype has final colors, typography, spacing, radii, and micro-interactions. Recreate pixel-perfectly using your codebase's conventions, but preserve the specific values in the Design Tokens section below.

## Screens / Views

### 1. Home (only screen)
- **Name:** Home / Upload
- **Purpose:** User drops/selects a receipt image → app "classifies" it → result appears as a chip caption and is appended to the Recent list.
- **Layout:**
  - Single centered column. Max-width `680px`. Horizontal padding `24px`. Top padding `72px`, bottom padding `120px`.
  - Content stack (top → bottom): Header block → Dropzone card → "Recent" section heading → History list (or empty state) → Footnote.

### Components

#### Header block (centered, `text-align: center`)
- **Logo mark:** `56×56` circle, white fill, `1px` border `var(--line)`, subtle shadow `0 1px 2px rgba(20,20,20,0.03), 0 6px 20px -12px rgba(20,20,20,0.12)`.
  - Inside: a `26×26` SVG of an abstract receipt — rectangle body (`6.5,3.5` → `19.5,22.5`, rx `1.5`, `1.4px` dark stroke, white fill), three horizontal content lines, and a zig-zag torn-edge path along the bottom. **No faces or avatars.**
- **Title:** "Receipt Classification" — Inter 600, `24px`, letter-spacing `-0.01em`, margin `18px 0 4px`.
- **Subtitle:** "Please drop in an image of a receipt." — Inter 400, `13.5px`, color `var(--ink-2)`.
- **Segmented tab:** pill container, `4px` inner padding, `1px` border `var(--line)`, background `var(--bg-soft)`, border-radius `999px`. Single button "Upload" in the selected state (white bg, shadow, dark text). Selected-state shadow: `0 1px 2px rgba(20,20,20,0.06), 0 0 0 1px var(--line)`. `13px` / 500 weight, `6px 16px` padding. Margin-top from subtitle `28px`.

#### Dropzone card
- **Card wrapper:** `background: var(--bg-card)`, `1px` border `var(--line)`, border-radius `14px`, `overflow: hidden`, margin-top `40px`.
- **Dropzone region:** `aspect-ratio: 16/10`, grid-centered content, `cursor: pointer`.
  - Hover: background shifts slightly darker warm-white.
  - Drag-over: background `var(--accent-soft)`, dashed `2px` `var(--accent)` outline inset `-10px`.
- **Empty state (inner stack, 14px gap, 24px padding):**
  - **Receipt placeholder:** `120px` wide, `3:4` aspect, `1px` border `var(--line-2)`, `6px` radius. Fill = 135°-angle repeating stripes alternating `oklch(0.93 0.004 80)` and `oklch(0.95 0.004 80)` at `6px` bands. Top and bottom have `8px` zig-zag torn edges (implemented via `::before` / `::after` with a `linear-gradient` sawtooth mask at `14px × 8px`).
  - **Label:** "**Drop a receipt** here, or <u>click to browse</u>" — `13.5px`, `var(--ink-2)`; the bold fragment in `var(--ink)`.
  - **Hint:** "png · jpg · heic — up to 10 mb" — JetBrains Mono, `11.5px`, uppercase, letter-spacing `0.02em`, color `var(--ink-3)`.
- **Preview state (after file chosen):** fills the dropzone, `var(--bg-soft)` background, `20px` padding. Image: `max-width/height: 100%`, `8px` radius, shadow `0 1px 2px rgba(0,0,0,0.04), 0 12px 36px -18px rgba(0,0,0,0.2)`. Empty-state children hidden.
- **Scanning overlay (while classifying):** full-cover, `rgba(255,255,255,0.55)` + `backdrop-filter: blur(2px)`. Centered pill: white bg, `1px` border `var(--line)`, `999px` radius, `8px 14px` padding, content = pulsing blue dot + text "Classifying receipt…". Dot animation: `pulse` 1.1s infinite ease-in-out, scales .85↔1 and opacity .35↔1.

#### Caption bar (below dropzone, inside same card)
- `1px` top border `var(--line)`, white bg, `14px 16px` padding, flex with space-between.
- **Left side:** classification chip + filename (monospace, `13px`, ellipsis on overflow).
- **Chip:** pill, `4px 10px`, `12px` / 500 weight, leading `6px` swatch dot. Empty state = muted grey ("Waiting for upload"). After classification, chip swaps to the category color pair (see Design Tokens → Category colors). During classification, text reads "Classifying…".
- **Right side — Clear button:** `1px` border `var(--line)`, transparent bg, `12px` text, `4px 10px` padding, `999px` radius. Hidden when no file loaded.

#### Recent section
- **Section heading:** `margin: 48px 0 12px`, flex space-between. Left: "RECENT" — `12px` / 600 weight, letter-spacing `0.06em`, uppercase, color `var(--ink-3)`. Right: item count "N items" — JetBrains Mono, `12px`, color `var(--ink-3)` (not uppercased).
- **History list:** white bg, `1px` border `var(--line)`, `14px` radius, rows separated by `1px` bottom borders (last row no border). Each row:
  - Grid `44px | 1fr | auto`, `14px` gap, `12px 14px` padding.
  - **Thumb:** `44×44`, `8px` radius, `1px` border `var(--line)`, background = the uploaded image, `cover`.
  - **Meta:** name (`13.5px` / 500, ellipsis) and timestamp (JetBrains Mono, `12px`, `var(--ink-3)`, format `YYYY-MM-DD HH:MM`).
  - **Chip:** same component as caption, colored by category.
- **Empty state:** when zero items — dashed-border box replacing the list: `1px dashed var(--line-2)`, `14px` radius, `22px 16px` padding, centered `13px` text "No receipts yet. Your classified receipts will appear here."

#### Footnote
- Centered, JetBrains Mono, `11.5px`, `var(--ink-3)`. Content: "proof of concept · v0.1".

## Interactions & Behavior

- **Click dropzone** (when no file) → opens native file picker (`<input type="file" accept="image/*">`).
- **Keyboard** → dropzone is `tabindex="0"`, role="button". Enter/Space opens picker.
- **Drag & drop** → `dragenter` / `dragover` apply `.is-over`; `dragleave` / `drop` remove it; `drop` reads `e.dataTransfer.files[0]`.
- **On file selected:**
  1. Read as data URL via FileReader.
  2. Swap dropzone to preview state, show filename in caption, set chip to "Classifying…" (no color).
  3. Show scanning overlay.
  4. Wait `900ms + rand(0–500ms)` (placeholder latency).
  5. Pick a category (stubbed) → hide overlay, set chip color + label, prepend `{name, cat, src, time}` to history, re-render list.
- **Clear button** → resets the dropzone to empty state. Does not remove history items.
- **Reset / classification do not persist** across refresh (in-memory only). Add localStorage if desired.

## State Management

Single feature state:
```ts
type Item = { name: string; cat: Category; src: string; time: string };
type State = { items: Item[] };
```
Transient UI state on the dropzone: `isOver`, `hasFile`, `isBusy`.

- `handleFile(file)` → triggers the classification flow.
- `classify(file)` → **replace the stub** with a real call. Should return a `Category`. Consider exposing confidence and, later, extracted fields (vendor, total, date).
- `reset()` → clears current file/preview/chip; leaves history intact.

## Design Tokens

### Colors (OKLCH)
```
--bg:        oklch(0.985 0.003 80)   /* page bg — warm near-white */
--bg-soft:   oklch(0.965 0.004 80)
--bg-card:   oklch(0.975 0.003 80)
--ink:       oklch(0.22 0.01 80)     /* primary text */
--ink-2:     oklch(0.45 0.01 80)     /* secondary text */
--ink-3:     oklch(0.62 0.008 80)    /* tertiary / meta text */
--line:      oklch(0.92 0.004 80)
--line-2:    oklch(0.88 0.005 80)

/* Single brand accent */
--accent:      oklch(0.55 0.08 250)
--accent-soft: oklch(0.94 0.03 250)

/* Status / category pairs */
--ok:        oklch(0.6  0.11 150)    /* Groceries */
--ok-soft:   oklch(0.95 0.04 150)
--warn:      oklch(0.7  0.13 70)     /* Dining */
--warn-soft: oklch(0.96 0.05 80)
```

### Category colors
| Category   | Text / dot                    | Background                  |
|------------|-------------------------------|-----------------------------|
| Groceries  | `oklch(0.6 0.11 150)`         | `oklch(0.95 0.04 150)`      |
| Dining     | `oklch(0.7 0.13 70)`          | `oklch(0.96 0.05 80)`       |
| Transport  | `oklch(0.55 0.08 250)`        | `oklch(0.94 0.03 250)`      |
| Utilities  | `oklch(0.5 0.1 300)`          | `oklch(0.95 0.035 300)`     |
| Retail     | `oklch(0.55 0.12 20)`         | `oklch(0.95 0.035 20)`      |

### Typography
- Body UI: **Inter** (Google Fonts), weights 400/500/600. Features `ss01`, `cv11` on.
- Monospace / meta: **JetBrains Mono**, weights 400/500.
- Scale used: `11.5px` (hints), `12px` / `12.5px` (chips, meta), `13px` / `13.5px` (body UI), `24px` (title).

### Spacing
Used ad-hoc rather than a strict scale. Recurring values: `4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 40, 48, 72, 120`.

### Radii
- Small chips/buttons pill: `999px`
- Inputs / thumbs: `8px`
- Placeholder: `6px`
- Cards, list, empty-state: `14px`

### Shadows
- Logo: `0 1px 2px rgba(20,20,20,0.03), 0 6px 20px -12px rgba(20,20,20,0.12)`
- Preview image: `0 1px 2px rgba(0,0,0,0.04), 0 12px 36px -18px rgba(0,0,0,0.2)`
- Scanning pill: `0 10px 30px -14px rgba(0,0,0,0.2)`
- Selected segmented button: `0 1px 2px rgba(20,20,20,0.06), 0 0 0 1px var(--line)`

## Assets
- **Logo SVG** — hand-authored, inline in the HTML. Abstract receipt (rect + 3 lines + zig-zag base). No third-party assets.
- **Placeholder receipt** — pure CSS: `repeating-linear-gradient` stripes + `::before` / `::after` pseudo-elements for torn edges. No images.
- **Fonts** — loaded from Google Fonts (`Inter`, `JetBrains Mono`). In your codebase, swap to `next/font` / equivalent.

## Suggested API shape (for the real classifier)

```
POST /api/classify
Content-Type: multipart/form-data
Body: { image: File }

Response 200:
{
  "category": "Groceries" | "Dining" | "Transport" | "Utilities" | "Retail",
  "description": string,       // short sentence summarizing the receipt
  "confidence": 0.0..1.0,      // optional
  "extracted": {               // optional, future
    "vendor": string | null,
    "total":  number | null,
    "currency": string | null,
    "date":   string | null    // ISO date
  }
}
```

## Files in this bundle
- `Receipt Classifier.html` — the full working prototype. Open it in a browser to see final behavior.
- `README.md` — this document.

## Implementation notes for Claude Code
- Rebuild as a **single-route** app (`/`) with a client component that owns the upload + history state.
- Keep the classifier behind an API route (`/api/classify`) so the client has no model keys.
- Persist history to `localStorage` (key suggestion: `receipt-classifier.items`) so a refresh keeps it.
- Keep the visual design **exactly** as specified; do not restyle with a component library's defaults.
- Respect accessibility: dropzone must be keyboard-operable (Enter/Space), chip state changes should be announced (`aria-live="polite"` on the list is already set; consider one on the chip too).
