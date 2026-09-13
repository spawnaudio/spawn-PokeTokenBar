import AppKit
import SwiftUI

/// Root Focus tab: companion + pinned clock or idle CTAs + usage glance.
/// Pet-off 0:00 / check-in / forfeit sit here when the overlay is not the host.
@MainActor
struct FocusTabView: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session
    @Environment(PopoverNavigation.self) private var nav

    private var l: L { companion.l }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                promptStack
                CompanionHeader(store: companion)
                if let current = session.session, current.issue.isPomodoro {
                    pomodoroClock(current)
                }
                linearSection
                TodayUsageSummary(compact: true, showsRefresh: true) {
                    nav.tab = .usage
                }
                .popoverCard()
                TimeXPView(store: store, companion: companion, compact: true)
                    .popoverCard()
            }
        }
    }

    @ViewBuilder
    private var linearSection: some View {
        if let current = session.session, !current.issue.isPomodoro {
            pinnedIssue(current)
        } else {
            idleLinearPrompt
        }
    }

    @ViewBuilder
    private var promptStack: some View {
        if let warning = session.forfeitPrompt {
            FocusForfeitWarningCard(warning: warning)
        } else if session.resetPrompt {
            FocusResetConfirmCard()
        } else if SessionPromptSurface.showsOnPopover(floatingPetEnabled: store.floatingPetEnabled),
                  session.prompt != .none
                    || SessionPromptSurface.showsPopoverCaption(
                        floatingPetEnabled: store.floatingPetEnabled,
                        prompt: session.prompt,
                        bubbleIsCritical: store.currentSpeechBubble?.isCritical == true) {
            PopoverSessionBanner()
        }
    }

    private func pinnedIssue(_ current: FocusSession) -> some View {
        let issue = store.linearIssue(id: current.issue.id) ?? current.issue.summary
        let clock = session.clockDisplay()
        let paused = current.userPaused || current.phase == .paused
        return VStack(alignment: .leading, spacing: 8) {
            PopoverSectionLabel(text: l.activeIssueSection)
            HStack(spacing: 6) {
                LinearIssueIDButton(identifier: current.issue.identifier, url: current.issue.url)
                Text(current.issue.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
            }
            HStack(alignment: .center, spacing: 10) {
                Text(clock.text)
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                if clock.overtime {
                    Text(l.overtimeAbbrev)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 4)
                FocusPauseButton(
                    paused: paused,
                    disabled: current.phase == .awaitingChoice,
                    pauseTitle: l.pauseTimer,
                    resumeTitle: l.resumeTimer
                ) {
                    session.togglePause()
                }
            }
            if let url = current.issue.url {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label(l.linearOpenIssue, systemImage: "arrow.up.right.square")
                }
                .tahoeButtonStyle(.accessory)
                .controlSize(.small)
            }
            LinearIssueStatusPicker(issue: issue, compact: false)
            FocusTimerControls()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popoverCard()
    }

    private func pomodoroClock(_ current: FocusSession) -> some View {
        let clock = session.clockDisplay()
        let paused = current.userPaused || current.phase == .paused
        return VStack(alignment: .leading, spacing: 8) {
            PopoverSectionLabel(text: l.pomodoroTitle)
            HStack(alignment: .center, spacing: 10) {
                Text(clock.text)
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                if clock.overtime {
                    Text(l.overtimeAbbrev)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 4)
                FocusPauseButton(
                    paused: paused,
                    disabled: current.phase == .awaitingChoice,
                    pauseTitle: l.pauseTimer,
                    resumeTitle: l.resumeTimer
                ) {
                    session.togglePause()
                }
            }
            FocusTimerControls()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popoverCard()
    }

    private var idleLinearPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.focusIdlePrompt)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Button(l.openLinearTab) { nav.tab = .linear }
                        .tahoeButtonStyle(.regular)
                    Button(l.todayDeskMenuOpen) { session.openDesk() }
                        .tahoeButtonStyle(.regular)
                }
                .controlSize(.regular)
                .fixedSize(horizontal: true, vertical: false)
                HStack(spacing: 8) {
                    Button { nav.tab = .linear } label: {
                        Image(systemName: "circle")
                    }
                    .tahoeButtonStyle(.regular)
                    .help(l.openLinearTab)
                    .accessibilityLabel(l.openLinearTab)
                    Button { session.openDesk() } label: {
                        Image(systemName: "calendar")
                    }
                    .tahoeButtonStyle(.regular)
                    .help(l.todayDeskMenuOpen)
                    .accessibilityLabel(l.todayDeskMenuOpen)
                }
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popoverCard()
    }
}
