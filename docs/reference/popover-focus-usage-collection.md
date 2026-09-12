---
summary: "Locked popover IA: Focus · Linear · Usage · Collection, nested Linear filters, Dex default, pin-to-Focus."
read_when:
  - Changing popover tabs, shell toolbar, Focus/Usage/Collection layout
  - Changing Linear pin, nested Linear filters, or Collection segments
  - Restyling popover chrome (Linear chips, cards, menu-bar panel attach/detach)
  - Changing the Today window (dual sidebars — see today-desk-sidebars.md)
---

# Popover Focus / Usage / Collection

Locked 2026-09-12. Implementation follows this spec; do not reopen root-tab count or flatten Linear.

This file lives under `docs/reference/` because the repo publishes only that docs tree (`docs/*` is gitignored).

## Root chrome

**NSWindow** (not a transient `NSPopover`). Click-outside and focus loss do **not** close it. Status-item click toggles visibility via `orderOut` (the attached window is not `.closable`, so `performClose` is a no-op). The close button and pet/open paths bring it forward if already shown. Hosting is still torn down on close (energy).

**Attached (default).** Borderless, not movable, always placed under the status item. Dragging does **not** undock it. Opaque shell (`NSColor.underPageBackgroundColor`) with an 8pt gap around a 12pt-rounded inset panel (`NSColor.controlBackgroundColor`) plus a hairline. Resizable: min **360×520**, attached max width **500pt**, height max **660**.

**Detached.** Only the toolbar detach button undocks. Then it is a titled, movable, resizable window with frame autosave `PokeTokenBarMenuBarPanel` and max width **720**. The same button snaps it back under the status item and locks it again.

Default size **360×640**. System light/dark. Cards: ~12pt continuous corners, `Color.primary` fill ~0.06 and a hairline. Lists stay **opaque and unboxed** — rows use hairline dividers and a hover fill, not a card per item. Root tabs sit on the shell toolbar. Sub-tabs live **inside** the inset panel (`TahoeTabBar` / `linearSegmentChrome`: filled control surface, brighter text, soft hairline). Dropdowns are quiet bordered chips (`TahoePopupMenu` / `linearChipChrome`), tinted to match status/priority. Issue IDs are muted text, not pills. Pause / Mark done / primary actions use the same filled Linear chip (`tahoeButtonStyle(.prominent)`). SF Pro. Caption2 tertiary section labels. Clock: large rounded `monospacedDigit`.

Compact layout tests still use `PopoverMetrics.width` (360). Live width is `\.popoverContentWidth`.

Do not restyle Collection / Dex / Shop **content** as Linear except the shared segment pills. Keep system light/dark via semantic `Color.primary` opacities — do not lock a Nordic Gray / Inter dark-only theme.

## Shell toolbar

Four labeled tabs (symbol + caption) sit on the darker outer shell: **Focus · Linear · Usage · Collection**. A back chevron appears when the tab is not Focus or Settings is open. Selected tab = Linear filled grey + hairline + primary text, **not** `Color.accentColor`. Then icon-only **detach/attach**, **Today** (calendar), and **Settings**. Quit lives in Settings, not on the bar. Refresh lives on Usage and Linear only.

Reopening from hidden always lands on **Focus** (`PopoverNavigation.reset()`). Clicking outside does not hide the panel, so the current tab stays. Settings remains an in-window swap, not a sheet.

## Focus

Pinned: companion (120pt sprite, no grey box, name, rarity, XP bar, flavor) → ACTIVE ISSUE id + title → large remaining/OT clock → Pause + Open issue. Usage glance (today total + provider split); tap opens the Usage tab. No Focus pin button. Pet-off prompts (0:00, check-in, forfeit warning) appear **on Focus** when the overlay is not visible.

Idle: same companion; copy “Select a Linear issue to focus”; **Pomo Timer** (opens the overlay setup island; clock starts only after **Start**) + **Open Linear** (switch tab) + **Open Today**. No in-progress list. Usage glance.

**Pomodoro.** Overlay chevron and Focus/Today idle open duration options (25 / 50 / 90) on the floating island (`FocusSessionStore.openPomodoroSetup`). **Start** begins a timer with no Linear issue (`FocusPinnedIssue.pomodoroID`). Same clock / XP / pause path; hide Linear ID, status, notes, Mark done. Pinning a Linear issue while a pomodoro is running uses the forfeit path.

## Linear

Keep nested tabs — do not flatten:

- Sub: Issues · Projects · Initiatives
- Issues: In progress · Completed today
- Projects: In progress · Production
- Initiatives: Active · Planned

Header: New issue + refresh (calendar is the trailing Today icon). Unboxed two-line rows: click the title to unfold team/project/assignee/labels/estimate/due plus markdown description (`LinearMarkdownText`). Trailing priority chip (Priority grey / Low blue / Medium yellow / High orange / Urgent red) + status chip tinted to the workflow type + pin. Hide empty fields. Completion XP when present. Projects/initiatives use the same unboxed row language; Initiatives use a gold `flag.fill`.

**Pin** starts the session and **switches to the Focus tab**. Do **not** auto-open Today from this pin. Today still opens from the calendar icon, the idle CTA, and the pet menu. Pinning from the Today desk is unchanged (`openDesk` as today).

## Today window

Not a popover tab. Dual sidebars (~920×680): left pin list, Focus-like hero, right inspector + log. See `docs/reference/today-desk-sidebars.md`.

## Usage

Today totals, provider split, official limits (stale / auth-expired / tap-to-load), Time XP toggle + cap. Refresh. No companion sprite.

## Collection

Inner **Bag | Dex | Shop**. **Default Dex**. Settings representative pick still deep-links to Dex. Bag candy still jumps to Focus after use. Shop wallet stays here.

## Overlay timer

The floating pet always shows a 32pt circular chevron button (not a tiny glyph). With a session it folds/expands the island. With no session it opens the Pomo Timer setup island (duration then Start). Clicks left of the sprite go to SwiftUI so the button is hittable.

## Localization

Route copy through `L` (`t(...)` for all seven languages). No Hangul in Swift UI sources. No `== "claude_code"` (or sibling literals) on generic Focus/Usage glance paths.
