---
summary: "Implementation tasks for Linear issue create and timer unfocus-forfeit."
read_when:
  - Implementing docs/reference/linear-issue-create-and-timer-controls.md
---

# Linear issue create and timer controls — plan

> Spec: `docs/reference/linear-issue-create-and-timer-controls.md`. Inline execution. TDD on parsers and FocusTick. Do not reopen proportional unfocus XP.

**Goal:** Shared New issue window from menubar, pet, and Today; timer reset / add time / Unfocus-forfeit.

**Architecture:** Split Linear catalog queries + `issueCreate`. Pure `FocusTick` clock/forfeit math. `FocusSessionStore` holds forfeit/reset prompts and never auto-pays leave-in-progress on pin-switch. One `NSWindow` composer (Today desk pattern).

## Tasks

1. Linear catalog types, `issueCreate` payload (omit empty optionals), parsers, client methods, tests.
2. `FocusTick.resetClock` / `addRemaining` / `unfocusForfeit` + tests.
3. `FocusSessionStore` pin/unfocus/reset/add-time/Create & Focus through forfeit warning.
4. `UsageStore.createLinearIssue` + last team id.
5. Composer window + three triggers. Localization en/ko/ja. LaunchWindowPolicy ids.
6. Island/Today timer chrome + red forfeit feedback.
7. `swift test` + v3 rebuild.
