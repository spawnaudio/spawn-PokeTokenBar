import AppKit
import SwiftUI

/// Dual-sidebar Today window. Closing it does not stop a running session.
@MainActor
final class TodayDeskController: NSObject, NSWindowDelegate {
    private let usage: UsageStore
    private let companion: CompanionStore
    private let session: FocusSessionStore
    private var window: NSWindow?

    init(usage: UsageStore, companion: CompanionStore, session: FocusSessionStore) {
        self.usage = usage
        self.companion = companion
        self.session = session
        super.init()
        session.onOpenDesk = { [weak self] in self?.open() }
    }

    func open() {
        NSApp.activate(ignoringOtherApps: true)
        if window == nil {
            window = makeWindow()
        } else if window?.contentView == nil {
            window?.contentView = hostedView()
            window?.title = L(companion.language).todayDeskWindowTitle
        }
        window?.makeKeyAndOrderFront(nil)
    }

    private func hostedView() -> NSView {
        NSHostingView(rootView:
            TodayDeskView()
                .environment(usage)
                .environment(companion)
                .environment(session)
                .environment(\.locale, companion.language.displayLocale)
        )
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: TodayDeskMetrics.defaultWidth,
                height: TodayDeskMetrics.defaultHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = L(companion.language).todayDeskWindowTitle
        window.identifier = NSUserInterfaceItemIdentifier(LaunchWindowPolicy.todayDeskIdentifier)
        // Frame only. Sidebar widths/collapse are UsageStore keys (`todayDeskLeftWidth` etc.).
        window.setFrameAutosaveName(LaunchWindowPolicy.todayDeskAutosaveName)
        window.contentMinSize = NSSize(
            width: TodayDeskMetrics.minWidth,
            height: TodayDeskMetrics.minHeight)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = hostedView()
        if window.frame.origin == .zero { window.center() }
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Keep the session on the overlay; only hide the desk.
        window?.contentView = nil
    }
}

@MainActor
struct TodayDeskView: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session

    private var l: L { companion.l }

    var body: some View {
        GeometryReader { geo in
            let containerWidth = max(0, geo.size.width - TodayDeskMetrics.contentPadding * 2)
            let resolved = store.todayDeskLayout.resolved(containerWidth: containerWidth)
            HStack(alignment: .top, spacing: 0) {
                if !resolved.leftCollapsed {
                    leftSidebar
                        .frame(width: resolved.leftWidth)
                        .clipped()
                }
                TodayDeskSplitter(
                    collapsed: resolved.leftCollapsed,
                    displayedWidth: resolved.leftWidth,
                    growsWhenDraggedPositive: true,
                    collapseLabel: l.collapseLeftSidebar,
                    expandLabel: l.expandLeftSidebar,
                    onToggle: { store.todayDeskLayout = store.todayDeskLayout.togglingLeft() },
                    onDragTo: { width in
                        store.todayDeskLayout = store.todayDeskLayout.settingLeftWidth(
                            width, containerWidth: containerWidth)
                    })
                centerColumn
                    .frame(minWidth: TodayDeskMetrics.minCenterWidth, maxWidth: .infinity, maxHeight: .infinity)
                TodayDeskSplitter(
                    collapsed: resolved.rightCollapsed,
                    displayedWidth: resolved.rightWidth,
                    growsWhenDraggedPositive: false,
                    collapseLabel: l.collapseRightSidebar,
                    expandLabel: l.expandRightSidebar,
                    onToggle: { store.todayDeskLayout = store.todayDeskLayout.togglingRight() },
                    onDragTo: { width in
                        store.todayDeskLayout = store.todayDeskLayout.settingRightWidth(
                            width, containerWidth: containerWidth)
                    })
                if !resolved.rightCollapsed {
                    rightSidebar
                        .frame(width: resolved.rightWidth)
                        .clipped()
                }
            }
            .padding(TodayDeskMetrics.contentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: TodayDeskMetrics.minWidth, minHeight: TodayDeskMetrics.minHeight)
        .background { PopoverMaterialBackground().ignoresSafeArea() }
        .task(id: store.linearIntegrationEnabled && store.linearAPIKeyConfigured) {
            guard store.linearIntegrationEnabled, store.linearAPIKeyConfigured else { return }
            _ = await store.refreshLinearIssues()
        }
    }

    // MARK: Left — date, pin list, composer, duration pickers

    private var leftSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.todayDeskWindowTitle)
                        .font(.title3.weight(.semibold))
                    Text(Date(), format: .dateTime.weekday(.wide).month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                refreshButton
            }

            PopoverSectionLabel(text: l.todayDeskPinList)
            pinList

            if !store.linearCompletedTodayIssues.isEmpty {
                PopoverSectionLabel(text: l.linearCompletedTodayTab)
                completedToday
            }

            Spacer(minLength: 8)
            NewLinearIssueButton(compact: false, showsTitle: true)
            durationPickers
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var refreshButton: some View {
        Button {
            Task { _ = await store.refreshLinearIssues() }
        } label: {
            if store.isRefreshingLinearIssues {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .tahoeButtonStyle(.accessory)
        .buttonBorderShape(.circle)
        .help(l.refreshNow)
        .disabled(!store.linearIntegrationEnabled || !store.linearAPIKeyConfigured || store.isRefreshingLinearIssues)
        .accessibilityLabel(l.refreshNow)
    }

    private var durationPickers: some View {
        @Bindable var session = session
        return VStack(alignment: .leading, spacing: 8) {
            labeledMinutes(l.plannedLengthLabel, selection: $session.plannedMinutes, presets: SessionXP.plannedPresets)
            labeledMinutes(l.checkInIntervalLabel, selection: $session.checkInMinutes, presets: SessionXP.checkInPresets)
        }
    }

    private func labeledMinutes(_ title: String, selection: Binding<Int>, presets: [Int]) -> some View {
        LinearPropertyRow(label: title) {
            HStack(spacing: 4) {
                TahoePopupMenu(
                    accessibilityLabel: title,
                    selectionTitle: l.minutesValue(selection.wrappedValue),
                    selection: selection
                ) {
                    ForEach(presets, id: \.self) { minutes in
                        Text(l.minutesValue(minutes)).tag(minutes)
                    }
                    if !presets.contains(selection.wrappedValue) {
                        Text(l.minutesValue(selection.wrappedValue)).tag(selection.wrappedValue)
                    }
                }
                Stepper("", value: selection, in: SessionXP.minMinutes...SessionXP.maxMinutes)
                    .labelsHidden()
                    .controlSize(.mini)
                    .help(l.customMinutes)
            }
        }
    }

    private var pinList: some View {
        Group {
            if store.linearInProgressIssues.isEmpty {
                Text(l.linearIssuesEmptyInProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(store.linearInProgressIssues) { issue in
                            TodayDeskPinRow(issue: issue, pinned: session.session?.issue.id == issue.id) {
                                session.pin(issue, openDesk: true)
                            }
                            if issue.id != store.linearInProgressIssues.last?.id {
                                Divider().opacity(0.6)
                            }
                        }
                    }
                }
            }
        }
        .frame(minHeight: 80, maxHeight: .infinity, alignment: .top)
    }

    private var completedToday: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(store.linearCompletedTodayIssues) { issue in
                    HStack(alignment: .center, spacing: 6) {
                        LinearStatusDot(type: issue.stateType)
                        Text(issue.title)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LinearIssueIDButton(identifier: issue.identifier, url: issue.issueURL)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    if issue.id != store.linearCompletedTodayIssues.last?.id {
                        Divider().opacity(0.6)
                    }
                }
            }
        }
        .frame(maxHeight: 140)
    }

    // MARK: Center — Focus hero

    @ViewBuilder
    private var centerColumn: some View {
        if let current = session.session {
            hero(current)
        } else {
            idleHero
        }
    }

    private var idleHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.focusIdlePrompt)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(l.todayDeskEmptyHint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .popoverCard()
    }

    private func hero(_ current: FocusSession) -> some View {
        let issue = store.linearIssue(id: current.issue.id) ?? current.issue.summary
        let clock = session.clockDisplay()
        let paused = current.userPaused || current.phase == .paused
        let canMarkDone = issue.completedStateId != nil
            || issue.teamStates.contains { $0.type.lowercased() == "completed" }
        return VStack(alignment: .leading, spacing: 12) {
            PopoverSectionLabel(text: l.activeIssueSection)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                LinearIssueIDButton(
                    identifier: current.issue.identifier,
                    url: current.issue.url,
                    style: .callout.weight(.medium))
                Text(current.issue.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(clock.text)
                    .font(.system(size: 58, weight: .medium, design: .rounded).monospacedDigit())
                if clock.overtime {
                    Text(l.overtimeAbbrev)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                FocusPauseButton(
                    paused: paused,
                    disabled: current.phase == .awaitingChoice,
                    pauseTitle: l.pauseTimer,
                    resumeTitle: l.resumeTimer
                ) {
                    session.togglePause()
                }
                if let url = current.issue.url {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label(l.linearOpenIssue, systemImage: "arrow.up.right.square")
                    }
                    .tahoeButtonStyle(.accessory)
                    .controlSize(.regular)
                }
                FocusMarkDoneButton(title: l.markDone, disabled: !canMarkDone) {
                    Task { await session.markIssueDone() }
                }
                Spacer(minLength: 4)
                LinearIssueStatusPicker(issue: issue, compact: false)
            }

            FocusTimerControls(compact: false)
            HStack {
                SessionNoteButton(compact: false)
                Spacer()
            }
            if session.isComposingNote {
                SessionNoteComposer(compact: false)
            } else if session.notePostFailed {
                Text(l.linearCommentFailed)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if let warning = session.forfeitPrompt {
                FocusForfeitWarningCard(warning: warning)
            } else if session.resetPrompt {
                FocusResetConfirmCard()
            } else {
                SessionPromptCard()
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .popoverCard()
    }

    // MARK: Right — inspector + log

    private var rightSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspector
            todayLog
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var inspector: some View {
        let issue: LinearIssueSummary? = {
            guard let current = session.session else { return nil }
            return store.linearIssue(id: current.issue.id) ?? current.issue.summary
        }()
        return VStack(alignment: .leading, spacing: 8) {
            PopoverSectionLabel(text: l.todayDeskDetailsSection)
            if let issue {
                let rows = LinearIssueInspector.fields(for: issue)
                if rows.isEmpty {
                    Text(l.todayDeskInspectorEmpty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, field in
                        inspectorRow(field)
                    }
                }
            } else {
                Text(l.todayDeskInspectorEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popoverCard()
    }

    private func inspectorRow(_ field: LinearIssueInspector.Field) -> some View {
        LinearPropertyRow(label: inspectorLabel(field.kind)) {
            HStack(spacing: 6) {
                if field.kind == .status {
                    LinearStatusDot(type: field.stateType)
                }
                Text(field.value)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func inspectorLabel(_ kind: LinearIssueInspector.Kind) -> String {
        switch kind {
        case .status: return l.linearStatusUnknown
        case .team: return l.todayDeskTeamLabel
        case .project: return l.todayDeskProjectLabel
        case .assignee: return l.todayDeskAssigneeLabel
        case .labels: return l.todayDeskLabelsLabel
        case .estimate: return l.todayDeskEstimateLabel
        case .due: return l.todayDeskDueLabel
        }
    }

    private var todayLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                PopoverSectionLabel(text: l.todayDeskLogTitle)
                Spacer()
                Text(l.driftCountLabel(session.todayDriftCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            let entries = session.todayLog
            if entries.isEmpty {
                Text(l.todayDeskLogEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(entries) { entry in
                            logRow(entry)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .popoverCard()
    }

    private func logRow(_ entry: FocusLogEntry) -> some View {
        Group {
            switch entry.kind {
            case .session:
                let duration = FocusClock.format(entry.durationSeconds ?? 0)
                let ot = (entry.overtimeSeconds ?? 0) > 0 ? FocusClock.format(entry.overtimeSeconds ?? 0) : ""
                Text(l.sessionLogLine(identifier: entry.issueIdentifier, duration: duration, overtime: ot))
            case .checkIn:
                let answer: String = {
                    switch entry.checkInAnswer {
                    case .yes: return l.checkInYes
                    case .no: return l.checkInNo
                    case .skip: return l.checkInSkip
                    case nil: return ""
                    }
                }()
                Text(l.checkInLogLine(
                    identifier: entry.issueIdentifier,
                    answer: answer,
                    notePosted: entry.notePosted))
            case .note:
                Text(l.sessionNoteLogLine(
                    identifier: entry.issueIdentifier,
                    note: entry.noteText ?? ""))
            case .forfeit:
                Text(l.forfeitLogLine(
                    identifier: entry.issueIdentifier,
                    xp: TokenFormatter.compact(entry.xpDelta ?? 0)))
            }
        }
        .font(.caption)
        .foregroundStyle(entry.usesDestructiveTint ? Color.red : Color.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Hairline column splitter + overlay-sized fold chevron. Drag resizes; chevron or
/// double-click collapses. Collapsed sidebars keep this strip so they can expand.
@MainActor
private struct TodayDeskSplitter: View {
    var collapsed: Bool
    var displayedWidth: CGFloat
    var growsWhenDraggedPositive: Bool
    var collapseLabel: String
    var expandLabel: String
    var onToggle: () -> Void
    var onDragTo: (CGFloat) -> Void

    @State private var dragOrigin: CGFloat?
    @State private var cursorPushed = false

    private var chevronName: String {
        if growsWhenDraggedPositive {
            return collapsed ? "chevron.right" : "chevron.left"
        }
        return collapsed ? "chevron.left" : "chevron.right"
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 0.5)
            Button(action: onToggle) {
                Image(systemName: chevronName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: TodayDeskMetrics.chevronHitSize,
                        height: TodayDeskMetrics.chevronHitSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(collapsed ? expandLabel : collapseLabel)
            .accessibilityLabel(collapsed ? expandLabel : collapseLabel)
        }
        .frame(width: TodayDeskMetrics.splitterWidth)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.resizeLeftRight.push()
                cursorPushed = true
            } else if cursorPushed {
                NSCursor.pop()
                cursorPushed = false
            }
        }
        .onDisappear {
            if cursorPushed {
                NSCursor.pop()
                cursorPushed = false
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    guard !collapsed else { return }
                    if dragOrigin == nil { dragOrigin = displayedWidth }
                    let delta = growsWhenDraggedPositive ? value.translation.width : -value.translation.width
                    onDragTo((dragOrigin ?? displayedWidth) + delta)
                }
                .onEnded { _ in
                    dragOrigin = nil
                }
        )
        .onTapGesture(count: 2, perform: onToggle)
    }
}

@MainActor
struct SessionPromptCard: View {
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }
    @FocusState private var checkInFieldFocused: Bool

    var body: some View {
        switch session.prompt {
        case .none:
            EmptyView()
        case .zeroTime:
            zeroTime
        case .checkIn:
            checkIn
        }
    }

    private var zeroTime: some View {
        let id = session.session?.issue.identifier ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            Text(l.timesUpPopupTitle(id))
                .font(.callout.weight(.semibold))
            Button(l.timesUpContinue) { session.continueOvertime() }
                .tahoeButtonStyle(.prominent)
            Button(l.timesUpFinishLeave) { session.finishLeavingInProgress() }
                .tahoeButtonStyle(.regular)
            Button(l.timesUpMarkDone) { Task { await session.markIssueDone() } }
                .tahoeButtonStyle(.regular)
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .tahoePromptChrome()
    }

    private var checkIn: some View {
        @Bindable var session = session
        let id = session.session?.issue.identifier ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            Text(l.stillOnIssue(id))
                .font(.callout.weight(.semibold))
            TextField(l.checkInNotePlaceholder, text: $session.checkInDraft)
                .textFieldStyle(.roundedBorder)
                .focused($checkInFieldFocused)
            HStack {
                Button(l.checkInYes) { Task { await session.answerCheckIn(.yes) } }
                    .tahoeButtonStyle(.prominent)
                Button(l.checkInNo) { Task { await session.answerCheckIn(.no) } }
                    .tahoeButtonStyle(.regular)
                Button(l.checkInSkip) { Task { await session.answerCheckIn(.skip) } }
                    .tahoeButtonStyle(.accessory)
                    .foregroundStyle(.secondary)
            }
            Text(l.checkInAddNote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .tahoePromptChrome()
        .onAppear { checkInFieldFocused = true }
    }
}

/// Pet-off host for 0:00 / check-in. Critical forfeit caption when the card isn't up.
@MainActor
struct PopoverSessionBanner: View {
    @Environment(UsageStore.self) private var store
    @Environment(FocusSessionStore.self) private var session

    var body: some View {
        if session.prompt != .none {
            SessionPromptCard()
        } else if let bubble = store.currentSpeechBubble,
                  SessionPromptSurface.showsPopoverCaption(
                    floatingPetEnabled: store.floatingPetEnabled,
                    prompt: session.prompt,
                    bubbleIsCritical: bubble.isCritical) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bubble.title)
                    .font(.caption.weight(.semibold))
                Text(bubble.body)
                    .font(.caption2)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.red.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

@MainActor
private struct TodayDeskPinRow: View {
    let issue: LinearIssueSummary
    let pinned: Bool
    let onPin: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            LinearStatusDot(type: issue.stateType)
            Button(action: onPin) {
                Text(issue.title)
                    .font(.callout.weight(pinned ? .medium : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            LinearIssueIDButton(identifier: issue.identifier, url: issue.issueURL)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            Color.primary.opacity(pinned ? 0.10 : (hovering ? 0.06 : 0)),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .onHover { hovering = $0 }
        .accessibilityAddTraits(pinned ? .isSelected : [])
    }
}

private extension Color {
    static var windowBackgroundColor: Color { Color(nsColor: .windowBackgroundColor) }
}
