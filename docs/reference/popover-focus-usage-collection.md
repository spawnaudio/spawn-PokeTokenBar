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

**Attached (default).** Borderless, not movable, always placed under the status item. Dragging does **not** undock it. Non-opaque window (`NSColor.clear`) with 12pt continuous rounding on the hosting view so the attached panel is not square. Linear-like shell (`MenuBarPanelMetrics.shellFill`: light `#F3F4F6`, dark charcoal) so the tab row sits on the sidebar chrome; 8pt gap around a 12pt-rounded inset canvas (`canvasFill`: light white, dark near-black) plus a hairline. Resizable: default **360×640**, min **360×520**, attached max **500×660**.

**Detached.** Only the toolbar detach button undocks. Then it is a movable, resizable window with `fullSizeContentView`, a hidden transparent titlebar, and traffic lights on the sidebar shell. Root tabs and nested Linear/Collection filters live in a **resizable left sidebar**; **detach / Today / Settings** sit on a **bottom bar**. Collapse control is under the traffic lights. Frame autosave `PokeTokenBarMenuBarPanel`. No 500pt cap — min width grows with the sidebar (content **360** + sidebar + splitter), min height **400**, max **2400**. The same bottom-bar button snaps it back under the status item and locks it again.

Default size **360×640**. System light/dark, matching Linear light (white page, `#F3F4F6` sidebar, white cards, ~10% black hairline) and a readable dark counterpart. Cards: ~12pt continuous corners, `cardFill` (white in light) and a `TahoeHairline` (0.5pt, appearance-aware). Buttons, idle tabs, accessory icons, chips, and cards all keep that hairline — not only the selected state. Lists stay **opaque and unboxed** — rows use hairline dividers and a hover fill, not a card per item. Attached: root tabs sit on the shell toolbar; sub-tabs live **inside** the inset panel (`TahoeTabBar` / `linearSegmentChrome`). Detached: those tabs move into the sidebar (`MenuBarSidebarNav`); in-content `TahoeTabBar`s hide. Dropdowns are quiet bordered chips (`TahoePopupMenu` / `linearChipChrome`), tinted to match status/priority. Issue IDs are muted text, not pills. Pause / Mark done / primary actions use the same filled Linear chip (`tahoeButtonStyle(.prominent)`). SF Pro. Caption2 tertiary section labels. Clock: large rounded `monospacedDigit`.

Compact layout tests still use `PopoverMetrics.width` (360). Live width is `\.popoverContentWidth`.

Do not restyle Collection / Dex / Shop **content** as Linear except the shared segment pills. Keep system light/dark via appearance-aware `MenuBarPanelMetrics` fills (Linear light mapping, not a locked Nordic Gray / Inter dark-only theme).

## Shell toolbar

**Attached.** Four labeled tabs (symbol + caption) sit on the outer shell: **Focus · Linear · Usage · Collection**. When a labeled cluster would wrap, that cluster becomes **icon-only** (`ViewThatFits`; root tabs, nested Linear/Collection bars, Focus CTAs, timer controls). A back chevron appears when the tab is not Focus or Settings is open. Selected tab = Linear filled grey + hairline + primary text, **not** `Color.accentColor`. Then icon-only **detach/attach**, **Today** (calendar), and **Settings**.

**Detached.** Sidebar (Linear-like grey) holds those root tabs plus nested Linear/Collection filters; labels collapse to icons when they would wrap. Collapse button sits under the traffic lights; drag the splitter to resize (UserDefaults `menuBarSidebarWidth` / `menuBarSidebarCollapsed`, default **176pt**, min **148**, max **260**). Bottom bar: **detach/attach**, **Today**, **Settings**. Quit lives in Settings, not on the bar. Refresh lives on Focus (today’s usage), Usage, and Linear.

Reopening from hidden always lands on **Focus** (`PopoverNavigation.reset()`). Clicking outside does not hide the panel, so the current tab stays. Settings remains an in-window swap, not a sheet.

## Focus

Pinned: companion **hero** on the canvas (120pt sprite + name / rarity / XP — **not** a hairline content card, no grey filled panel) → **Linear** card (idle Open Linear / Open Today, or the pinned issue clock). Pause + Open issue + status + timer controls on the Linear card. Usage glance (today total + provider split + refresh) in a hairline card; tap totals opens the Usage tab. Compact **Time XP** card. No Focus pin button. Pet-off prompts (0:00, check-in, forfeit warning) appear **on Focus** when the overlay is not visible.

Idle: same companion hero; copy “Select a Linear issue to focus” on the Linear card. No in-progress list. Usage glance + Time XP. Pomodoro entry points are hidden for now (store APIs remain for existing sessions). A running pomodoro still shows its clock on Focus.

**Pomodoro (disabled in UI).** `FocusSessionStore.openPomodoroSetup` / `startPomodoro` still exist for tests and an already-running session. Overlay chevron and Focus/Today idle no longer open the setup island. Pinning a Linear issue while a pomodoro is running still uses the forfeit path.

## Linear

Keep nested tabs — do not flatten:

- Sub: Issues · Projects · Initiatives
- Issues: In Progress · Planned · Todo · Completed Today
- Projects: In Progress · Production
- Initiatives: Active · Planned

Issue buckets (Linear workflow type, then name): **In Progress** = `started`; **Todo** = name contains `todo` or type `unstarted`; **Planned** = name contains `planned` or type `backlog` / `triage`. The issues query asks for those open types (`first: 100`) and splits client-side. Completed Today stays the `completedRecent` same-day filter.

Header: New issue + refresh (calendar is the trailing Today icon). Unboxed issue rows: the **whole highlighted row** toggles fold (title, chips, padding, whitespace) except dedicated controls (ID, priority, status, pin) and markdown text selection. Folded layout is title + ID on line 1; **team** (+ **due**) on the first metadata line with trailing priority / status / pin; **project** on the next line; **labels** on the line below that — not one shared chip strip. Team chip uses workspace tints: SPA/SPAWN red, PER/SQUEAKY aqua blue, HOU/HOUSE orange, STU/STUDY aqua green. Unfolded shows every inspector field plus a **rendered** Linear markdown preview (`LinearMarkdownText`: headings, lists, checklists, emphasis, code, quotes — not flattened caption text). Trailing priority chip (Priority grey / Low blue / Medium yellow / High orange / Urgent red) + status chip tinted to the workflow type + pin. Hide empty fields. Completion XP when present. Projects/initiatives use the same unboxed row language; Initiatives use a grey outline `flag`.

**Pin** starts the session and **switches to the Focus tab**. Do **not** auto-open Today from this pin. Today still opens from the calendar icon, the idle CTA, and the pet menu. Pinning from the Today desk is unchanged (`openDesk` as today).

## Today window

Not a popover tab. Dual sidebars (~920×680): left pin list, Focus-like hero, right inspector + log. See `docs/reference/today-desk-sidebars.md`.

## Usage

Today totals, provider split, official limits (stale / auth-expired / tap-to-load), Time XP toggle + cap. Refresh. No companion sprite.

## Collection

Inner **Bag | Dex | Shop**. **Default Dex**. Settings representative pick still deep-links to Dex. Bag candy still jumps to Focus after use. Shop wallet stays here.

## Overlay timer

The floating pet shows a 32pt circular chevron **only while a session is running** (fold/expand the island). Idle no longer opens Pomodoro setup. Clicks left of the sprite go to SwiftUI so the button is hittable.

## Localization

Route copy through `L` (`t(...)` for all seven languages). No Hangul in Swift UI sources. No `== "claude_code"` (or sibling literals) on generic Focus/Usage glance paths.
