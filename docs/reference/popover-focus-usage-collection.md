---
summary: "Locked popover IA: Focus · Linear · Usage · Collection, nested Linear filters, Dex default, pin-to-Focus."
read_when:
  - Changing popover tabs, bottom bar, Focus/Usage/Collection layout
  - Changing Linear pin, nested Linear filters, or Collection segments
  - Restyling popover chrome (glass, cards, 360pt width)
---

# Popover Focus / Usage / Collection

Locked 2026-09-12. Implementation follows this spec; do not reopen root-tab count or flatten Linear.

This file lives under `docs/reference/` because the repo publishes only that docs tree (`docs/*` is gitignored).

## Root chrome

Width **360pt**. System light/dark. `NSVisualEffectView` material `.popover` (or `.ultraThinMaterial`). Cards: ~12pt continuous corners and a hairline. Lists stay **opaque** — Tahoe glass (`#available(macOS 26, *)`) is only on the **bottom bar** and the Focus **Pause** button (`.glassProminent` / `.borderedProminent`). SF Pro. Caption2 tertiary section labels. Clock: large rounded `monospacedDigit`.

## Bottom bar

Four labeled tabs (symbol + caption): **Focus · Linear · Usage · Collection**. Then icon-only **Today** (calendar) and **Settings**. Quit lives in Settings, not on the bar. Refresh lives on Usage and Linear only.

Reopening the popover always lands on **Focus** (`PopoverNavigation.reset()`). Settings remains an in-popover swap, not a sheet.

## Focus

Pinned: companion (sprite, name, rarity, XP bar, flavor) → ACTIVE ISSUE id + title → large remaining/OT clock → Pause + Open issue. Usage glance (today total + provider split); tap opens the Usage tab. No Focus pin button. Pet-off prompts (0:00, check-in, forfeit warning) appear **on Focus** when the overlay is not visible.

Idle: same companion; copy “Select a Linear issue to focus”; **Open Linear** (switch tab) + **Open Today**. No in-progress list. Usage glance.

## Linear

Keep nested tabs — do not flatten:

- Sub: Issues · Projects · Initiatives
- Issues: In progress · Completed today
- Projects: In progress · Production
- Initiatives: Active · Planned

Header: New issue + refresh (calendar is the trailing Today icon). Dense rows from already-fetched `LinearIssueSummary`: status dot+name, ID pill, title, priority, teamKey, projectName, assigneeName, truncated labels, estimate, dueDate, one muted description line. Hide empty fields. Completion XP when present. Project/initiative headers: lead/owner, targetDate, status, issue count.

**Pin** starts the session and **switches to the Focus tab**. Do **not** auto-open Today from this pin. Today still opens from the calendar icon, the idle CTA, and the pet menu. Pinning from the Today desk is unchanged (`openDesk` as today).

## Usage

Today totals, provider split, official limits (stale / auth-expired / tap-to-load), Time XP toggle + cap. Refresh. No companion sprite.

## Collection

Inner **Bag | Dex | Shop**. **Default Dex**. Settings representative pick still deep-links to Dex. Bag candy still jumps to Focus after use. Shop wallet stays here.

## Localization

Route copy through `L` (`t(...)` for all seven languages). No Hangul in Swift UI sources. No `== "claude_code"` (or sibling literals) on generic Focus/Usage glance paths.
