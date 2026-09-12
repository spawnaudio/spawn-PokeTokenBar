---
summary: "Today desk dual-sidebar IA: Linear pin list, Focus-like hero, inspector + log."
read_when:
  - Changing the Today window layout, chrome, or pin/openDesk behavior
  - Restyling Today to match the popover Focus / Linear language
  - Changing Today sidebar resize, collapse, or persisted width keys
---

# Today desk dual sidebars

Locked with the popover IA (2026-09-12). Today is still a titled `NSWindow`, not a fifth popover tab.

## Window

Identifier **`PokeTokenBar.TodayDesk`** (LaunchWindowPolicy unchanged). Autosave `PokeTokenBarTodayDesk` stores the **window frame only**. Sidebar widths and collapse flags are separate UserDefaults keys (see Resize / collapse). Style: titled, closable, miniaturizable, resizable. Default **920×680**, minimum width fits three columns (~860pt): left 212 + center ≥360 + right 232 + splitter strips + padding. Closing Today does **not** stop the session. Collapsing a sidebar gives that space to the center; the window min size stays the three-column width so frame autosave cannot shrink below the clock.

Chrome matches the menu-bar panel: system light/dark, `NSVisualEffectView` / `.ultraThinMaterial`, ~12pt continuous hairline cards on the hero/inspector panels, SF Pro, caption2 tertiary labels, large rounded monospaced clock, muted Linear IDs + status dots. Tahoe glass (`#available(macOS 26)`) only on **Pause** and **Mark done**. Pin/completed lists are unboxed rows. The inspector uses muted-label / bright-value property rows (`LinearPropertyRow`). The menu-bar panel is a smaller sticky window (360–720pt), not a fifth popover tab and not this desk.

No Quit. Trailing refresh lives in the left header.

## Columns

```
┌────────────┬─────────────────────────────┬─────────────┐
│ LEFT       │ CENTER                      │ RIGHT       │
│ ~212pt     │ Focus-like hero             │ ~232pt      │
└────────────┴─────────────────────────────┴─────────────┘
```

**Left** — navigation + pin list (Linear-like). Date / Today title. In-progress issues (status dot, title, muted ID); click title to Focus (`openDesk: true`). Pinned row uses a quiet filled surface, not an accent-tinted card. Nested **Completed today** if any. New issue + same composer. Planned / check-in duration pickers as property rows in the sidebar footer. No Projects / Initiatives boards (those stay on the popover Linear tab). Default **212pt**, resizable/collapsible (see below).

**Center** — issue + clock as the star (no companion HQ). ACTIVE ISSUE id + title, huge remaining/OT clock, Pause / Open issue / Mark done / status, timer controls, notes, then 0:00 / check-in / forfeit / reset prompts. Empty: Focus idle copy plus “pin from the left list.”

**Right** — inspector + log. Pinned issue metadata already fetched as property rows (muted 72pt label, brighter value): status, team, project, assignee, labels, estimate, due (hide empty). Today’s log (sessions, check-ins, notes, forfeits) + drift count. Forfeit rows stay red. No calendar rail or health charts. Default **232pt**, resizable/collapsible (see below).

## Resize / collapse

Hairline splitters (popover chrome, not source-list) sit between left|center and center|right. Pointer is `NSCursor.resizeLeftRight`. Overlay-sized chevron (~32pt hit, 9pt glyph) on each splitter; double-click the splitter also toggles.

**Resize.** Drag a splitter. Each sidebar clamps to **min 160pt** and **max min(320pt, 40% of the column container)**. Center keeps **≥360pt** so the clock never collapses. Preferred widths persist; shrinking the window clamps **on screen only** and does not rewrite prefs.

**Collapse.** Chevron (or double-click) sets content width to 0. The splitter/chevron stays so the sidebar can expand. Preferred width is unchanged. Expanding restores that width (clamped to the current window). Center takes the freed space when one or both sides are collapsed.

**Persisted UserDefaults keys** (`UsageStore`, same pattern as `floatingPetIslandFolded`):

| Key | Default | Meaning |
|---|---|---|
| `todayDeskLeftWidth` | 212 | Preferred left width (pt) |
| `todayDeskRightWidth` | 232 | Preferred right width (pt) |
| `todayDeskLeftCollapsed` | false | Left content hidden |
| `todayDeskRightCollapsed` | false | Right content hidden |

These are **not** the window autosave name `PokeTokenBarTodayDesk`. Do not store sidebar state in the frame autosave blob.

## Pin behavior (do not break)

- Pin from **Today** list: existing `openDesk` (brings/keeps Today).
- Pin from **popover Linear**: switches to Focus, does **not** auto-open Today.
- Pet overlay, menubar countdown, pet-off popover prompts unchanged.
