import AppKit
import SwiftUI

/// Status menu shared by the Linear tab, overlay island, and Today desk.
@MainActor
struct LinearIssueStatusPicker: View {
    let issue: LinearIssueSummary
    var compact: Bool = true

    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session

    private var l: L { L(store.localizationLanguage) }

    var body: some View {
        let busy = store.updatingLinearIssueID == issue.id
        let states = issue.teamStates
        let selectedID = issue.stateId
            ?? states.first(where: { $0.name == issue.stateName })?.id
            ?? ""
        let title = states.first(where: { $0.id == selectedID })?.name
            ?? issue.stateName
            ?? l.linearStatusUnknown
        return TahoePopupMenu(
            accessibilityLabel: l.linearStatusHelp,
            selectionTitle: title,
            selection: Binding(
                get: { selectedID },
                set: { newID in
                    guard let state = states.first(where: { $0.id == newID }) else { return }
                    Task { await changeStatus(to: state) }
                }
            ),
            size: compact ? .mini : .small,
            tint: LinearWorkflowTint.color(for: issue.stateType)
        ) {
            if states.isEmpty {
                Text(title).tag(selectedID)
            }
            ForEach(states) { state in
                Text(state.name).tag(state.id)
            }
        }
        .disabled(states.isEmpty || store.updatingLinearIssueID != nil)
        .opacity(busy ? 0.45 : 1)
        .overlay {
            if busy { ProgressView().controlSize(.mini) }
        }
        .help(states.isEmpty ? l.linearStatusUnavailable : l.linearStatusHelp)
    }

    private func changeStatus(to state: LinearWorkflowState) async {
        let currentID = issue.stateId
            ?? issue.teamStates.first(where: { $0.name == issue.stateName })?.id
        guard state.id != currentID else { return }
        let completed = await store.updateLinearIssueState(issue, stateID: state.id)
        if let completed {
            let outcome = companion.creditLinearCompletions([completed])
            store.announceLinearCompletions(outcome.newlyCredited)
            session.handleLinearCompletion(completed)
        }
    }
}

/// Linear workflow tint for the 8pt status dot (popover rows + Today pin list / inspector).
enum LinearWorkflowTint {
    static func color(for type: String?) -> Color {
        switch (type ?? "").lowercased() {
        case "completed": return .green
        case "started": return .yellow
        case "canceled", "cancelled": return .secondary
        default: return .blue
        }
    }
}

enum LinearPriorityTint {
    static let gold = Color(red: 0.85, green: 0.65, blue: 0.18)

    static func color(for value: Int?) -> Color {
        switch LinearPriorityLevel.from(value) {
        case .none: return .secondary
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

enum LinearTeamTint {
    static let spawnRed = Color(red: 0.91, green: 0.28, blue: 0.29)
    static let squeakyAqua = Color(red: 0.22, green: 0.72, blue: 0.84)
    static let houseOrange = Color(red: 0.96, green: 0.58, blue: 0.20)
    static let studyGreen = Color(red: 0.22, green: 0.78, blue: 0.58)

    static func color(forKey key: String?, name: String? = nil) -> Color? {
        switch (key ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "SPA": return spawnRed
        case "PER": return squeakyAqua
        case "HOU": return houseOrange
        case "STU": return studyGreen
        default: break
        }
        let nameUpper = (name ?? "").uppercased()
        if hasTeamToken(nameUpper, "SPAWN") { return spawnRed }
        if hasTeamToken(nameUpper, "SQUEAKY") { return squeakyAqua }
        if hasTeamToken(nameUpper, "HOUSE") { return houseOrange }
        if hasTeamToken(nameUpper, "STUDY") { return studyGreen }
        return nil
    }

    private static func hasTeamToken(_ name: String, _ token: String) -> Bool {
        if name == token || name == "[\(token)]" { return true }
        if name.contains("[\(token)]") { return true }
        return name.split { !$0.isLetter }.map(String.init).contains(token)
    }
}

/// Linear-flavored markdown (headings, lists, checklists, emphasis, code, quotes).
enum LinearMarkdown {
    enum Block {
        case heading(Int, String)
        case paragraph(String)
        case quote(String)
        case code(String)
        case list([(checked: Bool?, text: String)], ordered: Bool)
        case divider
    }

    static func attributed(_ source: String) -> AttributedString {
        attributedInline(source)
    }

    static func attributedInline(_ source: String) -> AttributedString {
        let trimmed = preprocess(source).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return AttributedString() }
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible
        return (try? AttributedString(markdown: trimmed, options: options)) ?? AttributedString(trimmed)
    }

    static func preprocess(_ source: String) -> String {
        var text = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if let mention = try? NSRegularExpression(
            pattern: #"@\[([^\]]+)\]\((?:user|issue|document|project|initiative|comment):[^)]+\)"#
        ) {
            text = mention.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text),
                withTemplate: "**@$1**")
        }
        text = text.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"</p>"#, with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<p[^>]*>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        return text
    }

    static func blocks(_ source: String) -> [Block] {
        let normalized = preprocess(source)
        var blocks: [Block] = []
        var paragraph: [String] = []
        var listItems: [(checked: Bool?, text: String)] = []
        var listOrdered = false
        var quoteLines: [String] = []
        var codeLines: [String] = []
        var inFence = false

        func flushParagraph() {
            let text = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            paragraph.removeAll()
            guard !text.isEmpty else { return }
            blocks.append(.paragraph(text))
        }
        func flushList() {
            guard !listItems.isEmpty else { return }
            blocks.append(.list(listItems, ordered: listOrdered))
            listItems.removeAll()
        }
        func flushQuote() {
            let text = quoteLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            quoteLines.removeAll()
            guard !text.isEmpty else { return }
            blocks.append(.quote(text))
        }

        for raw in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if inFence {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                    inFence = false
                } else {
                    codeLines.append(line)
                }
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                flushParagraph(); flushList(); flushQuote()
                inFence = true
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph(); flushList(); flushQuote()
                continue
            }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph(); flushList(); flushQuote()
                blocks.append(.divider)
                continue
            }
            if trimmed.hasPrefix("> ") || trimmed == ">" {
                flushParagraph(); flushList()
                quoteLines.append(trimmed.hasPrefix("> ") ? String(trimmed.dropFirst(2)) : "")
                continue
            } else if !quoteLines.isEmpty {
                flushQuote()
            }
            if let heading = parseHeading(trimmed) {
                flushParagraph(); flushList(); flushQuote()
                blocks.append(.heading(heading.0, heading.1))
                continue
            }
            if let item = parseListItem(trimmed) {
                flushParagraph(); flushQuote()
                if !listItems.isEmpty, listOrdered != item.ordered {
                    flushList()
                }
                listOrdered = item.ordered
                listItems.append((item.checked, item.text))
                continue
            }
            if !listItems.isEmpty { flushList() }
            paragraph.append(trimmed)
        }
        if inFence { blocks.append(.code(codeLines.joined(separator: "\n"))) }
        flushQuote(); flushList(); flushParagraph()
        return blocks
    }

    private static func parseHeading(_ line: String) -> (Int, String)? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for character in line {
            if character == "#" { level += 1 } else { break }
        }
        guard (1...6).contains(level), line.count > level else { return nil }
        let rest = line.dropFirst(level)
        guard rest.first == " " else { return nil }
        let text = rest.dropFirst().trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (level, text)
    }

    private static func parseListItem(_ line: String) -> (ordered: Bool, checked: Bool?, text: String)? {
        if let match = line.range(of: #"^[-*+]\s+\[(x|X| )\]\s+"#, options: .regularExpression) {
            let marker = line[match].contains("x") || line[match].contains("X")
            return (false, marker, String(line[match.upperBound...]))
        }
        if let match = line.range(of: #"^[-*+]\s+"#, options: .regularExpression) {
            return (false, nil, String(line[match.upperBound...]))
        }
        if let match = line.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            return (true, nil, String(line[match.upperBound...]))
        }
        return nil
    }
}

@MainActor
struct LinearMarkdownText: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(LinearMarkdown.blocks(source).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: LinearMarkdown.Block) -> some View {
        switch block {
        case .heading(let level, let text):
            markdownText(text)
                .font(headingFont(level))
        case .paragraph(let text):
            markdownText(text)
        case .quote(let text):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary.opacity(0.25))
                    .frame(width: 2)
                markdownText(text)
                    .foregroundStyle(.secondary)
            }
        case .code(let text):
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(TahoeHairline.idle, lineWidth: TahoeHairline.width)
                }
        case .list(let items, let ordered):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 6) {
                        listMarker(item.checked, ordered: ordered, index: index)
                        markdownText(item.text)
                    }
                }
            }
        case .divider:
            Divider()
        }
    }

    private func markdownText(_ source: String) -> some View {
        Text(LinearMarkdown.attributedInline(source))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title3.weight(.semibold)
        case 2: return .headline
        default: return .subheadline.weight(.semibold)
        }
    }

    @ViewBuilder
    private func listMarker(_ checked: Bool?, ordered: Bool, index: Int) -> some View {
        if let checked {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .font(.caption)
                .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                .frame(width: 14)
        } else if ordered {
            Text("\(index + 1).")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
        } else {
            Text("•")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 14)
        }
    }
}

@MainActor
struct LinearPriorityButton: View {
    let issue: LinearIssueSummary
    var compact: Bool = true

    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }
    private var tint: Color { LinearPriorityTint.color(for: issue.priority) }

    var body: some View {
        Menu {
            ForEach(LinearPriorityLevel.allCases, id: \.rawValue) { option in
                Button(l.linearPriorityChip(option == .none ? nil : option.rawValue)) {
                    Task { await store.updateLinearIssuePriority(issue, priority: option.rawValue) }
                }
            }
        } label: {
            Text(l.linearPriorityChip(issue.priority))
                .foregroundStyle(tint)
        }
        .menuIndicator(.hidden)
        .linearChipChrome(tint: tint)
        .controlSize(compact ? .mini : .small)
        .disabled(store.updatingLinearIssueID != nil)
        .help(l.linearPriorityChip(issue.priority))
        .accessibilityLabel(l.linearPriorityChip(issue.priority))
    }
}

@MainActor
struct LinearIssueMetadataList: View {
    let issue: LinearIssueSummary

    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }

    var body: some View {
        let rows = LinearIssueInspector.fields(for: issue).filter { $0.kind != .status }
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, field in
                LinearPropertyRow(label: label(field.kind)) {
                    if field.kind == .team {
                        LinearTagChip(
                            text: field.value,
                            tint: LinearTeamTint.color(forKey: issue.teamKey, name: issue.teamName))
                    } else {
                        Text(field.value)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func label(_ kind: LinearIssueInspector.Kind) -> String {
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
}

@MainActor
struct LinearStatusDot: View {
    var type: String?
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(LinearWorkflowTint.color(for: type))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

@MainActor
struct LinearIssueIDButton: View {
    let identifier: String
    var url: URL?
    var style: Font = .caption2

    /// Help uses the companion language; English fallback is never shown as a Hangul literal.
    @Environment(CompanionStore.self) private var companion

    var body: some View {
        Button {
            if let url { NSWorkspace.shared.open(url) }
        } label: {
            Text(identifier)
                .font(style)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
        .help(companion.l.linearOpenIssue)
    }
}

/// Rewards and timer summary on a completed Linear issue card. Omits anything we did not persist.
@MainActor
struct LinearIssueCompletionStats: View {
    let issue: LinearIssueSummary

    @Environment(CompanionStore.self) private var companion
    @Environment(FocusSessionStore.self) private var session

    private var l: L { companion.l }
    private var isCompleted: Bool {
        issue.completedAt != nil || (issue.stateType ?? "").lowercased() == "completed"
    }

    var body: some View {
        let xp = isCompleted ? companion.linearIssueXP(id: issue.id) : nil
        let history = isCompleted ? session.history(forIssueID: issue.id) : nil
        if isCompleted, xp != nil || history != nil {
            VStack(alignment: .leading, spacing: 2) {
                xpRow(xp, history: history)
                if let history {
                        timerRow(history)
                        finishRow(history.finish)
                        checkInRows(history.checkIns)
                        noteRows(history.notes ?? [])
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func xpRow(_ xp: LinearIssueXPRecord?, history: FocusIssueHistory?) -> some View {
        HStack(spacing: 8) {
            if let xp, xp.xp > 0 {
                Text(l.linearCompletionXPAmount(TokenFormatter.compact(xp.xp)))
            }
            if let history, history.sessionXP > 0 {
                Text(l.sessionXPAmount(TokenFormatter.compact(history.sessionXP)))
            }
        }
    }

    @ViewBuilder
    private func timerRow(_ history: FocusIssueHistory) -> some View {
        let plannedMinutes = max(0, Int((history.plannedSeconds / 60).rounded(.down)))
        HStack(spacing: 8) {
            Text(l.plannedDurationLine(l.minutesValue(plannedMinutes)))
            Text(FocusClock.format(history.durationSeconds))
                .monospacedDigit()
            if history.overtimeSeconds > 0 {
                Text(l.overtimeDurationLine(FocusClock.format(history.overtimeSeconds)))
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func finishRow(_ finish: FocusFinishKind) -> some View {
        switch finish {
        case .doneOnTime:
            Text(l.focusFinishedOnTime)
        case .doneOvertime:
            Text(l.focusFinishedOvertime)
        case .leftInProgress:
            Text(l.focusFinishedLeftInProgress)
        case .forfeited:
            Text(l.focusFinishedForfeited)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func checkInRows(_ checkIns: [FocusCheckInSummary]) -> some View {
        ForEach(Array(checkIns.enumerated()), id: \.offset) { _, checkIn in
            VStack(alignment: .leading, spacing: 1) {
                Text(l.focusCheckInLine(answer: checkInAnswerLabel(checkIn.answer), notePosted: checkIn.notePosted))
                if let note = checkIn.note, !note.isEmpty {
                    Text(note)
                        .lineLimit(2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func checkInAnswerLabel(_ answer: CheckInAnswer) -> String {
        switch answer {
        case .yes: return l.checkInYes
        case .no: return l.checkInNo
        case .skip: return l.checkInSkip
        }
    }

    @ViewBuilder
    private func noteRows(_ notes: [String]) -> some View {
        ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
            Text(note)
                .lineLimit(2)
                .foregroundStyle(.tertiary)
        }
    }
}

@MainActor
struct LinearFocusButton: View {
    let issue: LinearIssueSummary
    var compact: Bool = true
    /// Today desk keeps the default (open Today). Linear tab passes false.
    var openDeskOnPin: Bool = true
    var onPinned: (() -> Void)? = nil

    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }
    private var isPinned: Bool { session.session?.issue.id == issue.id }

    var body: some View {
        Button {
            session.pin(issue, openDesk: openDeskOnPin)
            onPinned?()
        } label: {
            Text(isPinned ? l.focusingNow : l.focusAction)
                .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
        }
        .linearChipChrome()
        .controlSize(compact ? .mini : .small)
    }
}

@MainActor
struct NewLinearIssueButton: View {
    var compact: Bool = true
    var showsTitle: Bool = false

    @Environment(UsageStore.self) private var store
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }

    var body: some View {
        Group {
            if showsTitle {
                ViewThatFits(in: .horizontal) {
                    titledButton
                        .fixedSize(horizontal: true, vertical: false)
                    iconButton
                }
            } else {
                iconButton
            }
        }
        .controlSize(compact ? .mini : .small)
        .disabled(!store.canComposeLinearIssue)
        .help(store.canComposeLinearIssue ? l.newLinearIssue : l.linearIssuesNeedsSetup)
        .accessibilityLabel(l.newLinearIssue)
    }

    private var titledButton: some View {
        Button {
            session.openComposer()
        } label: {
            Label(l.newLinearIssue, systemImage: "plus")
        }
        .linearChipChrome()
    }

    private var iconButton: some View {
        Button {
            session.openComposer()
        } label: {
            Image(systemName: "plus")
        }
        .tahoeButtonStyle(.accessory)
        .buttonBorderShape(.circle)
    }
}

@MainActor
struct FocusForfeitWarningCard: View {
    let warning: FocusForfeitWarning

    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.forfeitConfirmTitle)
                .font(.callout.weight(.semibold))
            Text(l.forfeitConfirmBody)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(l.forfeitLeaveInProgressLine(TokenFormatter.compact(warning.leaveInProgressXP)))
                .font(.caption)
            Text(l.forfeitDonePackageLine(TokenFormatter.compact(warning.donePackageXP)))
                .font(.caption)
            HStack {
                Button(l.cancel) { session.cancelForfeit() }
                    .tahoeButtonStyle(.regular)
                Button(l.forfeitConfirmAction) {
                    Task { await session.confirmForfeit() }
                }
                .tahoeButtonStyle(.prominent)
                .tint(.red)
            }
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .tahoePromptChrome()
    }
}

@MainActor
struct FocusResetConfirmCard: View {
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }

    var body: some View {
        let planned = l.minutesValue(session.plannedMinutes)
        return VStack(alignment: .leading, spacing: 8) {
            Text(l.resetTimerConfirmTitle)
                .font(.callout.weight(.semibold))
            Text(l.resetTimerConfirmBody(planned))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button(l.cancel) { session.cancelReset() }
                    .tahoeButtonStyle(.regular)
                Button(l.resetTimer) { session.confirmReset() }
                    .tahoeButtonStyle(.prominent)
            }
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .tahoePromptChrome()
    }
}

@MainActor
struct FocusTimerControls: View {
    var compact: Bool = true

    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }
    private let presets = [5, 10, 15, 30]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            labeledControls
                .fixedSize(horizontal: true, vertical: false)
            iconControls
        }
        .controlSize(compact ? .mini : .small)
    }

    private var labeledControls: some View {
        HStack(spacing: compact ? 4 : 8) {
            Button(l.resetTimer) { session.requestReset() }
                .disabled(!session.canResetClock)
                .tahoeButtonStyle(.regular)
            Menu {
                ForEach(presets, id: \.self) { minutes in
                    Button(l.addTimeMinutes(minutes)) {
                        session.addRemainingMinutes(minutes)
                    }
                }
            } label: {
                TahoeMenuLabel(text: l.addTime)
            }
            .menuIndicator(.hidden)
            .linearChipChrome()
            .disabled(!session.canAddRemainingTime)
            Button(l.unfocusAction) { session.requestUnfocus() }
                .foregroundStyle(.red)
                .tahoeButtonStyle(.regular)
        }
    }

    private var iconControls: some View {
        HStack(spacing: compact ? 4 : 8) {
            Button { session.requestReset() } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(!session.canResetClock)
            .tahoeButtonStyle(.regular)
            .help(l.resetTimer)
            .accessibilityLabel(l.resetTimer)
            Menu {
                ForEach(presets, id: \.self) { minutes in
                    Button(l.addTimeMinutes(minutes)) {
                        session.addRemainingMinutes(minutes)
                    }
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuIndicator(.hidden)
            .linearChipChrome()
            .disabled(!session.canAddRemainingTime)
            .help(l.addTime)
            .accessibilityLabel(l.addTime)
            Button { session.requestUnfocus() } label: {
                Image(systemName: "xmark")
            }
            .foregroundStyle(.red)
            .tahoeButtonStyle(.regular)
            .help(l.unfocusAction)
            .accessibilityLabel(l.unfocusAction)
        }
    }
}
