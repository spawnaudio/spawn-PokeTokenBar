---
summary: "Locked popover IA: Focus · Linear · Usage · Collection, nested Linear filters, Dex default, pin-to-Focus."
read_when:
  - Changing popover tabs, bottom bar, Focus/Usage/Collection layout
  - Changing Linear pin, nested Linear filters, or Collection segments
  - Restyling popover chrome (glass, cards, menu-bar panel size)
  - Changing the Today window (dual sidebars — see today-desk-sidebars.md)
---

# Popover Focus / Usage / Collection

Locked 2026-09-12. Implementation follows this spec; do not reopen root-tab count or flatten Linear.

This file lives under `docs/reference/` because the repo publishes only that docs tree (`docs/*` is gitignored).

## Root chrome

Sticky **NSWindow** (not a transient `NSPopover`). Click-outside and focus loss do **not** close it. Status-item click toggles; the close button and pet/open paths bring it forward if already shown. Hosting is still torn down on close (energy).

Default size **360×640**. Resizable: min **360×520**, max **720×660** (Today is 920×680). Frame autosave `PokeTokenBarMenuBarPanel`. System light/dark. `NSVisualEffectView` material `.popover`. Cards: ~12pt continuous corners and a hairline. Lists stay **opaque and unboxed** — rows use hairline dividers and a hover fill, not a card per item. Tahoe glass (`#available(macOS 26, *)`) is only on the **bottom bar**, Focus **Pause**, and **Mark done**. Sub-tabs are quiet selected pills (`TahoeTabBar` / `linearSegmentChrome`). Dropdowns are quiet bordered chips (`TahoePopupMenu` / `linearChipChrome`), not glass. Issue IDs are muted text, not pills. SF Pro. Caption2 tertiary section labels. Clock: large rounded `monospacedDigit`.

Compact layout tests still use `PopoverMetrics.width` (360). Live width is `\.popoverContentWidth`.

## Bottom bar

Four labeled tabs (symbol + caption): **Focus · Linear · Usage · Collection**. Then icon-only **Today** (calendar) and **Settings**. Quit lives in Settings, not on the bar. Refresh lives on Usage and Linear only.

Reopening from hidden always lands on **Focus** (`PopoverNavigation.reset()`). Clicking outside does not hide the panel, so the current tab stays. Settings remains an in-window swap, not a sheet.

## Focus

Pinned: companion (sprite, name, rarity, XP bar, flavor) → ACTIVE ISSUE id + title → large remaining/OT clock → Pause + Open issue. Usage glance (today total + provider split); tap opens the Usage tab. No Focus pin button. Pet-off prompts (0:00, check-in, forfeit warning) appear **on Focus** when the overlay is not visible.

Idle: same companion; copy “Select a Linear issue to focus”; **Open Linear** (switch tab) + **Open Today**. No in-progress list. Usage glance.

## Linear

Keep nested tabs — do not flatten:

- Sub: Issues · Projects · Initiatives
- Issues: In progress · Completed today
- Projects: In progress · Production
- Initiatives: Active · Planned

Header: New issue + refresh (calendar is the trailing Today icon). Unboxed two-line rows from already-fetched `LinearIssueSummary`: status dot, bright title, muted ID, metadata chips (`LinearTagChip`), truncated description, trailing status chip + pin. Hide empty fields. Completion XP when present. Project/initiative group headers are a full-width quiet strip (chevron, name, lead/owner, targetDate, status, count) — not extra cards.

**Pin** starts the session and **switches to the Focus tab**. Do **not** auto-open Today from this pin. Today still opens from the calendar icon, the idle CTA, and the pet menu. Pinning from the Today desk is unchanged (`openDesk` as today).

## Today window

Not a popover tab. Dual sidebars (~920×680): left pin list, Focus-like hero, right inspector + log. See `docs/reference/today-desk-sidebars.md`.

## Usage

Today totals, provider split, official limits (stale / auth-expired / tap-to-load), Time XP toggle + cap. Refresh. No companion sprite.

## Collection

Inner **Bag | Dex | Shop**. **Default Dex**. Settings representative pick still deep-links to Dex. Bag candy still jumps to Focus after use. Shop wallet stays here.

## Localization

Route copy through `L` (`t(...)` for all seven languages). No Hangul in Swift UI sources. No `== "claude_code"` (or sibling literals) on generic Focus/Usage glance paths.
