# Maccy (cr-enhance fork) — Release Notes

A heavily reworked Maccy, inspired by [Ditto](https://ditto-cp.sourceforge.io/) (Windows).
The goal: see more, find faster, click less. The original shows one cramped line per
item, hides matches you search for, collapses the window under you, and buries every
action in a bottom menu. This fork fixes all of that.

## Search that actually shows you the match

- **Matched text is colored** (Ditto-style red `#D45247` by default) — pick any color
  in Settings → Appearance. Yellow-background, bold, italic, underline still available.
  *Original: bold only by default — nearly invisible.*
- **Long items jump to the match.** If the match sits deep inside a long clip, the row
  re-windows around it with `…` marking the cut-off start/end.
  *Original: the match stayed hidden past the truncation — you matched, but saw nothing.*
- **Text search means text.** Image items are excluded from search results.
  *Original: searching a word surfaced screenshots that happened to contain it via OCR.*
- **The preview highlights every match** of the search query too, not just the list.
- **Exact match only, always fast.** The fuzzy/regex/mixed search modes are gone —
  they scanned every item with expensive scoring on the main thread and could
  freeze typing on a big history. Exact search stays instant even at 50,000 items.

## Mask — screen-share your clipboard safely

- **One click masks any item** (eye button beside pin): `Hello I am Crews` becomes
  `Hell•••••••••ews` — first 4 and last 3 characters visible, everything between
  replaced by password dots of the exact same length (both counts configurable).
- Applies everywhere the item shows: list, search snippets, and the preview.
- **Search still works on the real text**, and highlights land on the dots at the
  exact matched positions — search "Hello" and `Hell•` lights up.
- Purely visual: pasting pastes the real content; the mask persists until you
  unmask. *Original: nothing — your copied passwords sat in plain sight.*

## A list you can actually read

- **Up to 3 lines per item** (configurable 1–10). *Original: 1 line, take it or leave it.*
- **Real line breaks and tabs** in the list, just like the preview.
  *Original: littered rows with `⏎` and `⇥` symbols.*
- **Uniform row heights**, text/images top-aligned — a clean grid instead of jumping rows.
- **Zebra striping** (alternating backgrounds) + **configurable gap** between items
  (default 10pt). *Original: an undifferentiated wall of text.*
- **Full-width rows** — no wasted side margins.
- **Selection color is configurable**, defaults to a calm light gray instead of the
  loud accent blue; selected text auto-switches black/white for contrast.
- **Color clips** (`#RRGGBB`) get a proper rounded swatch preview.
- No more `⌘1–9` badge clutter (shortcuts still work), no "Maccy" label in the header.

## Pinning that makes sense

- **Pin icon leads every row**: faint outline to pin, orange filled pin to unpin —
  one click, right where the item is. *Original: pinning hidden in a toolbar/menu.*
- **Pinned items stand out**: always one line tall with a light yellow tint.
- **Unpinning returns the item to the top** of the list, like a fresh copy.
  *Original: it sank back to wherever its old timestamp put it.*

## A window that behaves

- **True light/dark/system theme setting.** Light mode is pure white `#ffffff`
  with black text. *Original: always a translucent blur showing your wallpaper through.*
- **Background opacity slider** (default 100% = fully opaque).
- **Fixed popup height** — searching down to 2 results no longer collapses the window.
- **Popup height slider** (Appearance settings, default 100%): shrink the popup as a
  percentage of the window height — the top edge stays put, only the bottom rises.
- **Font size slider** (Appearance settings, default 13 pt): one text size for the
  whole popup — list, search, preview. Row heights scale with it.
- **Fixed preview width (400pt)** — no more mysteriously shrinking preview pane.
- **Preview opens instantly** — slide animation removed.
- **"Pin Preview" setting** (on by default): the preview pane shows automatically every
  time the popup opens.
- **Taller search box**, flush to the top-left corner, with a proper
  "Type to search…" placeholder.

## Less clutter, more power

- **Cog menu**: a gear icon next to the search box holds Preferences and Quit; the
  permanent bottom footer is gone. Clear / Clear all live in Preferences → Storage.
- **One copy per text**: re-copying the same text from another app replaces the old
  entry and keeps the latest formats. *Original: near-duplicates piled up because
  each app attaches different styling metadata.*
- **Duplicate lookup at database speed**: finding the old copy is a single targeted
  database query instead of walking every stored item, so copying stays instant
  even with tens of thousands of items.
- **Whitespace-only copies** (spaces, tabs, newlines) are ignored entirely.
- **QR code scanner**: select an image item and hit the QR button — the first detected
  code's content is copied as a new clip. *Original: only OCR text extraction.*
- **10,000 items by default, up to 50,000.** *Original: 200 by default, capped at 999.*
- **Hotkey: `⌘` + `` ` ``** *(original: `⇧⌘C`)*.

## Build

- Builds on Xcode 16.x again (`NSGlassEffectView` guarded behind `#if compiler(>=6.2)`).
