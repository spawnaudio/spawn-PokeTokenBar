import AppKit
import SwiftUI

/// Closest SF Symbols to Linear’s chrome (issue circle / project hexagon / initiative flag).
private enum LinearChromeSymbol {
    static let issue = "circle"
    static let project = "hexagon"
    static let initiative = "flag"
}

@MainActor
private enum LinearRootTab: Hashable {
    case issues
    case projects
    case initiatives
}

@MainActor
private enum LinearIssuesTab: Hashable {
    case inProgress
    case completedToday
}

@MainActor
private enum LinearProjectsTab: Hashable {
    case inProgress
    case production
}

@MainActor
private enum LinearInitiativesTab: Hashable {
    case active
    case planned
}

@MainActor
struct LinearIntegrationView: View {
    let store: UsageStore
    @Environment(CompanionStore.self) private var companion
    @Environment(PopoverNavigation.self) private var nav
    @State private var selectedRoot: LinearRootTab = .issues
    @State private var selectedIssuesTab: LinearIssuesTab = .inProgress
    @State private var selectedProjectsTab: LinearProjectsTab = .inProgress
    @State private var selectedInitiativesTab: LinearInitiativesTab = .active

    private var l: L { companion.l }

    private var visibleIssues: [LinearIssueSummary] {
        switch selectedIssuesTab {
        case .completedToday: return store.linearCompletedTodayIssues
        case .inProgress: return store.linearInProgressIssues
        }
    }

    private var visibleProjects: [LinearProjectSummary] {
        store.linearProjects.filter { project in
            switch selectedProjectsTab {
            case .inProgress:
                return LinearClient.matchesProjectInProgressTab(
                    name: project.statusName, type: project.statusType)
            case .production:
                return LinearClient.matchesProjectProduction(
                    name: project.statusName, type: project.statusType)
            }
        }
    }

    private var visibleInitiatives: [LinearInitiativeSummary] {
        store.linearInitiatives.filter { initiative in
            switch selectedInitiativesTab {
            case .active:
                return LinearClient.matchesInitiativeActive(name: initiative.statusName)
            case .planned:
                return LinearClient.matchesInitiativePlanned(name: initiative.statusName)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                NewLinearIssueButton(showsTitle: true)
                Spacer()
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
            }

            TahoeTabBar(selection: $selectedRoot, items: [
                TahoeTabItem(.issues, title: l.linearIssuesTab, symbol: LinearChromeSymbol.issue),
                TahoeTabItem(.projects, title: l.linearProjectsTab, symbol: LinearChromeSymbol.project),
                TahoeTabItem(.initiatives, title: l.linearInitiativesTab, symbol: LinearChromeSymbol.initiative),
            ])

            if !store.linearIntegrationEnabled || !store.linearAPIKeyConfigured {
                Text(l.linearIssuesNeedsSetup)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if selectedRoot == .issues {
                    TahoeTabBar(selection: $selectedIssuesTab, items: [
                        TahoeTabItem(.inProgress, title: l.linearInProgressTab, symbol: "circle"),
                        TahoeTabItem(.completedToday, title: l.linearCompletedTodayTab, symbol: "checkmark"),
                    ])
                } else if selectedRoot == .projects {
                    TahoeTabBar(selection: $selectedProjectsTab, items: [
                        TahoeTabItem(.inProgress, title: l.linearInProgressTab, symbol: LinearChromeSymbol.project),
                        TahoeTabItem(.production, title: l.linearProductionTab, symbol: "cube"),
                    ])
                } else if selectedRoot == .initiatives {
                    TahoeTabBar(selection: $selectedInitiativesTab, items: [
                        TahoeTabItem(.active, title: l.linearActiveTab, symbol: LinearChromeSymbol.initiative),
                        TahoeTabItem(.planned, title: l.linearPlannedTab, symbol: "calendar"),
                    ])
                }

                if let updated = store.linearIssuesUpdatedAt {
                    HStack(spacing: 4) {
                        Text(l.linearLastSynced)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(updated, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if store.linearIssuesError != nil {
                    Text(l.linearIssuesSyncFailed)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                switch selectedRoot {
                case .issues:
                    issuesList
                case .projects:
                    containerList(
                        items: visibleProjects.map { LinearContainerRow(project: $0) },
                        emptyText: selectedProjectsTab == .production
                            ? l.linearProjectsEmptyProduction
                            : l.linearProjectsEmpty,
                        openHelp: l.linearOpenProject)
                case .initiatives:
                    containerList(
                        items: visibleInitiatives.map { LinearContainerRow(initiative: $0) },
                        emptyText: selectedInitiativesTab == .planned
                            ? l.linearInitiativesEmptyPlanned
                            : l.linearInitiativesEmpty,
                        openHelp: l.linearOpenInitiative)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: store.linearIntegrationEnabled && store.linearAPIKeyConfigured) {
            guard store.linearIntegrationEnabled, store.linearAPIKeyConfigured else { return }
            _ = await store.refreshLinearIssues()
        }
    }

    @ViewBuilder
    private var issuesList: some View {
        if visibleIssues.isEmpty {
            Text(selectedIssuesTab == .completedToday ? l.linearIssuesEmptyCompleted : l.linearIssuesEmptyInProgress)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 4)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleIssues) { issue in
                        issueCard(issue)
                        if issue.id != visibleIssues.last?.id {
                            Divider().opacity(0.6)
                        }
                    }
                }
            }
        }
    }

    private func containerList(
        items: [LinearContainerRow],
        emptyText: String,
        openHelp: String
    ) -> some View {
        Group {
            if items.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 4)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { row in
                            LinearFoldableRow(row: row, openHelp: openHelp) {
                                if row.issues.isEmpty {
                                    Text(l.linearContainerEmptyIssues)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 4)
                                } else {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(row.issues) { issue in
                                            issueCard(issue)
                                            if issue.id != row.issues.last?.id {
                                                Divider().opacity(0.6)
                                            }
                                        }
                                    }
                                }
                            }
                            if row.id != items.last?.id {
                                Divider().opacity(0.6)
                            }
                        }
                    }
                }
            }
        }
    }

    private func issueCard(_ issue: LinearIssueSummary) -> some View {
        LinearIssueEntityRow(issue: issue) {
            nav.showFocus()
        }
    }
}

/// Unboxed issue row. The highlighted row toggles fold; dedicated controls stay dedicated.
@MainActor
private struct LinearIssueEntityRow: View {
    let issue: LinearIssueSummary
    let onPin: () -> Void

    @State private var hovering = false
    @State private var expanded = false

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    LinearStatusDot(type: issue.stateType)
                    Text(issue.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(expanded ? nil : 2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .allowsHitTesting(false)

                LinearIssueIDButton(identifier: issue.identifier, url: issue.issueURL)
            }

            HStack(alignment: .center, spacing: 4) {
                foldedTeamLine
                    .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                    .allowsHitTesting(false)
                LinearPriorityButton(issue: issue)
                LinearIssueStatusPicker(issue: issue)
                LinearFocusButton(issue: issue, openDeskOnPin: false, onPinned: onPin)
                    .opacity(hovering || expanded ? 1 : 0.55)
            }

            if !expanded {
                foldedProjectLine
                foldedLabelsLine
            }

            if expanded {
                LinearIssueMetadataList(issue: issue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                if let text = issue.descriptionText, !text.isEmpty {
                    LinearMarkdownText(source: text)
                }
                LinearIssueCompletionStats(issue: issue)
                    .allowsHitTesting(false)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { expanded.toggle() }
            } label: {
                rowShape
                    .fill(Color.primary.opacity(hovering || expanded ? 0.06 : 0))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(rowShape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(issue.title)
            .accessibilityAddTraits(expanded ? .isSelected : [])
        }
        .contentShape(rowShape)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(expanded ? .isSelected : [])
    }

    @ViewBuilder
    private var foldedTeamLine: some View {
        let chips = foldedTeamChips
        if !expanded, !chips.isEmpty {
            chipRow(chips)
        }
    }

    @ViewBuilder
    private var foldedProjectLine: some View {
        if let project = issue.projectName, !project.isEmpty {
            LinearTagChip(text: project, tint: nil)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var foldedLabelsLine: some View {
        let labels = Array(issue.labelNames.prefix(4))
        if !labels.isEmpty {
            chipRow(labels.map { (text: $0, tint: nil as Color?) })
                .allowsHitTesting(false)
        }
    }

    private var foldedTeamChips: [(text: String, tint: Color?)] {
        var chips: [(text: String, tint: Color?)] = []
        if let key = issue.teamKey, !key.isEmpty {
            chips.append((key, LinearTeamTint.color(forKey: key, name: issue.teamName)))
        } else if let name = issue.teamName, !name.isEmpty {
            chips.append((name, LinearTeamTint.color(forKey: nil, name: name)))
        }
        if let due = issue.dueDate {
            chips.append((due.formatted(.dateTime.month(.abbreviated).day()), nil))
        }
        return chips
    }

    @ViewBuilder
    private func chipRow(_ chips: [(text: String, tint: Color?)]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                LinearTagChip(text: chip.text, tint: chip.tint)
            }
        }
    }
}

private struct LinearContainerRow: Identifiable {
    var id: String
    var name: String
    var url: URL?
    var statusName: String?
    var leadOrOwner: String?
    var targetDate: Date?
    var descriptionText: String?
    var symbol: String
    var issues: [LinearIssueSummary]

    var symbolTint: Color { .secondary }

    init(project: LinearProjectSummary) {
        id = project.id
        name = project.name
        url = project.url
        statusName = project.statusName ?? project.statusType
        leadOrOwner = project.leadName
        targetDate = project.targetDate
        descriptionText = project.descriptionText
        symbol = LinearChromeSymbol.project
        issues = project.issues
    }

    init(initiative: LinearInitiativeSummary) {
        id = initiative.id
        name = initiative.name
        url = initiative.url
        statusName = initiative.statusName
        leadOrOwner = initiative.ownerName
        targetDate = initiative.targetDate
        descriptionText = initiative.descriptionText
        symbol = LinearChromeSymbol.initiative
        issues = initiative.issues
    }
}

/// Unboxed two-line project/initiative row. Click unfolds metadata, markdown, and issues.
@MainActor
private struct LinearFoldableRow<Content: View>: View {
    let row: LinearContainerRow
    let openHelp: String
    @ViewBuilder let content: () -> Content

    @State private var expanded = false
    @State private var hoveringHeader = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) { expanded.toggle() }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .frame(width: 10)
                        Image(systemName: row.symbol)
                            .font(.caption2)
                            .foregroundStyle(row.symbolTint)
                            .frame(width: 12)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.name)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if !expanded {
                                collapsedMeta
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let url = row.url {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .controlSize(.mini)
                    .help(openHelp)
                }
            }

            if expanded {
                expandedMeta
                if let text = row.descriptionText, !text.isEmpty {
                    LinearMarkdownText(source: text)
                }
                content()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            Color.primary.opacity(hoveringHeader || expanded ? 0.06 : 0),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hoveringHeader = $0 }
        .accessibilityAddTraits(expanded ? .isSelected : [])
    }

    @ViewBuilder
    private var collapsedMeta: some View {
        let chips = metaChips
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, text in
                        LinearTagChip(text: text)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var expandedMeta: some View {
        let chips = metaChips
        if !chips.isEmpty {
            FlexibleChipWrap(chips: chips)
        }
    }

    private var metaChips: [String] {
        var chips: [String] = []
        if let status = row.statusName, !status.isEmpty { chips.append(status) }
        if let person = row.leadOrOwner, !person.isEmpty { chips.append(person) }
        if let target = row.targetDate {
            chips.append(target.formatted(.dateTime.month(.abbreviated).day()))
        }
        chips.append("\(row.issues.count)")
        return chips
    }
}

@MainActor
private struct FlexibleChipWrap: View {
    let chips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(chips.chunked(by: 3).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, text in
                        LinearTagChip(text: text)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private extension Array {
    func chunked(by size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var rows: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let next = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            rows.append(Array(self[index..<next]))
            index = next
        }
        return rows
    }
}
