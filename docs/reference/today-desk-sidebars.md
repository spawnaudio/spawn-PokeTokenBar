---
summary: "Today desk dual-sidebar IA: Linear pin list, Focus-like hero, inspector + log."
read_when:
  - Changing the Today window layout, chrome, or pin/openDesk behavior
  - Restyling Today to match the popover Focus / Linear language
---

# Today desk dual sidebars

Locked with the popover IA (2026-09-12). Today is still a titled `NSWindow`, not a fifth popover tab.

## Window

Identifier **`PokeTokenBar.TodayDesk`** (LaunchWindowPolicy unchanged). Autosave `PokeTokenBarTodayDesk`. Style: titled, closable, miniaturizable, resizable. Default **920×680**, minimum width fits three columns (~860pt): left 212 + center ≥360 + right 232 + gaps/padding. Closing Today does **not** stop the session.

Chrome matches the popover: system light/dark, `NSVisualEffectView` / `.ultraThinMaterial`, ~12pt continuous hairline cards, SF Pro, caption2 tertiary labels, large rounded monospaced clock, Linear ID pills + status dots. Tahoe glass (`#available(macOS 26)`) only on **Pause** and **Mark done**. Lists stay opaque.

No Quit. Trailing refresh lives in the left header.

## Columns

```
┌────────────┬─────────────────────────────┬─────────────┐
│ LEFT       │ CENTER                      │ RIGHT       │
│ ~212pt     │ Focus-like hero             │ ~232pt      │
└────────────┴─────────────────────────────┴─────────────┘
```

**Left** — navigation + pin list (Linear-like). Date / Today title. In-progress issues (status dot, ID pill, title); click title to Focus (`openDesk: true`). Pinned row highlighted. Nested **Completed today** if any. New issue + same composer. Planned / check-in duration pickers in the sidebar footer. No Projects / Initiatives boards (those stay on the popover Linear tab).

**Center** — issue + clock as the star (no companion HQ). ACTIVE ISSUE id + title, huge remaining/OT clock, Pause / Open issue / Mark done / status, timer controls, notes, then 0:00 / check-in / forfeit / reset prompts. Empty: Focus idle copy plus “pin from the left list.”

**Right** — inspector + log. Pinned issue metadata already fetched: status, team, project, assignee, labels, estimate, due (hide empty). Today’s log (sessions, check-ins, notes, forfeits) + drift count. Forfeit rows stay red. No calendar rail or health charts.

## Pin behavior (do not break)

- Pin from **Today** list: existing `openDesk` (brings/keeps Today).
- Pin from **popover Linear**: switches to Focus, does **not** auto-open Today.
- Pet overlay, menubar countdown, pet-off popover prompts unchanged.
