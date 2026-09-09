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

## A list you can actually read

- **Up to 3 lines per item** (configurable 1–10). *Original: 1 line, take it or leave it.*
- **Uniform row heights**, text/images top-aligned — a clean grid instead of jumping rows.
- **Zebra striping** (alternating backgrounds) + **configurable gap** between items
  (default 10pt). *Original: an undifferentiated wall of text.*
- **Full-width rows** — no wasted side margins.
- **Selection color is configurable**, defaults to a calm light gray instead of the
  loud accent blue; selected text auto-switches black/white for contrast.
- **Color clips** (`#RRGGBB`) get a proper rounded swatch preview.
- No more `⌘1–9` badge clutter (shortcuts still work), no "Maccy" label in the header.

## A window that behaves

- **True light/dark/system theme setting.** Light mode is pure white `#ffffff`
  with black text. *Original: always a translucent blur showing your wallpaper through.*
- **Background opacity slider** (default 100% = fully opaque).
- **Fixed popup height** — searching down to 2 results no longer collapses the window.
- **Preview opens instantly** — slide animation removed.
- **Pin = pin the preview pane** (on by default): the preview shows every time you open
  the popup. *Original: pin only reordered items.*

## Less clutter, more capacity

- **Cog menu**: Clear / Preferences / About / Quit moved into a gear icon next to the
  search box. The permanent bottom footer is gone.
- **10,000 items by default, up to 50,000.** *Original: 200 by default, capped at 999.*
- **Hotkey: `⌘` + `` ` ``** *(original: `⇧⌘C`)*.

## Build

- Builds on Xcode 16.x again (`NSGlassEffectView` guarded behind `#if compiler(>=6.2)`).
