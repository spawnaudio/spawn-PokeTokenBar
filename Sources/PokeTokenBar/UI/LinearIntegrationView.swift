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
                        TahoeTabItem(.inProgress, title: l.linearInProgressTab),
                        TahoeTabItem(.completedToday, title: l.linearCompletedTodayTab),
                    ])
                } else if selectedRoot == .projects {
                    TahoeTabBar(selection: $selectedProjectsTab, items: [
                        TahoeTabItem(.inProgress, title: l.linearInProgressTab),
                        TahoeTabItem(.production, title: l.linearProductionTab),
                    ])
                } else if selectedRoot == .initiatives {
                    TahoeTabBar(selection: $selectedInitiativesTab, items: [
                        TahoeTabItem(.active, title: l.linearActiveTab),
                        TahoeTabItem(.planned, title: l.linearPlannedTab),
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
        .frame(maxWidth: .infinity, minHeight: 520, maxHeight: .infinity, alignment: .top)
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

/// Unboxed two-line issue row: status + bright title, muted ID, chips, trailing actions.
@MainActor
private struct LinearIssueEntityRow: View {
    let issue: LinearIssueSummary
    let onPin: () -> Void

    @Environment(CompanionStore.self) private var companion
    @State private var hovering = false

    private var l: L { companion.l }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                LinearStatusDot(type: issue.stateType)
                Text(issue.title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LinearIssueIDButton(identifier: issue.identifier, url: issue.issueURL)
            }

            HStack(alignment: .center, spacing: 4) {
                chipRow
                Spacer(minLength: 4)
                LinearIssueStatusPicker(issue: issue)
                LinearFocusButton(issue: issue, openDeskOnPin: false, onPinned: onPin)
                    .opacity(hovering ? 1 : 0.55)
            }

            if let text = issue.descriptionText, !text.isEmpty {
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            LinearIssueCompletionStats(issue: issue)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.primary.opacity(hovering ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var chipRow: some View {
        let chips = metaChips
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(chips, id: \.self) { LinearTagChip(text: $0) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metaChips: [String] {
        var chips: [String] = []
        if issue.priority != nil {
            chips.append(l.linearPriority(issue.priority))
        }
        if let key = issue.teamKey, !key.isEmpty { chips.append(key) }
        if let project = issue.projectName, !project.isEmpty { chips.append(project) }
        if let assignee = issue.assigneeName, !assignee.isEmpty { chips.append(assignee) }
        if !issue.labelNames.isEmpty {
            chips.append(issue.labelNames.prefix(3).joined(separator: ", "))
        }
        if let estimate = issue.estimate { chips.append("E\(estimate)") }
        if let due = issue.dueDate {
            chips.append(due.formatted(.dateTime.month(.abbreviated).day()))
        }
        return chips
    }
}

private struct LinearContainerRow: Identifiable {
    var id: String
    var name: String
    var url: URL?
    var statusName: String?
    var leadOrOwner: String?
    var targetDate: Date?
    var symbol: String
    var issues: [LinearIssueSummary]

    init(project: LinearProjectSummary) {
        id = project.id
        name = project.name
        url = project.url
        statusName = project.statusName ?? project.statusType
        leadOrOwner = project.leadName
        targetDate = project.targetDate
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
        symbol = LinearChromeSymbol.initiative
        issues = initiative.issues
    }
}

/// Whole header row toggles fold; the open-in-Linear button does not.
@MainActor
private struct LinearFoldableRow<Content: View>: View {
    let row: LinearContainerRow
    let openHelp: String
    @ViewBuilder let content: () -> Content

    @State private var expanded = false
    @State private var hoveringHeader = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) { expanded.toggle() }
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .frame(width: 10)
                        Image(systemName: row.symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                            HStack(spacing: 6) {
                                if let status = row.statusName {
                                    Text(status)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if let person = row.leadOrOwner, !person.isEmpty {
                                    Text(person)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                if let target = row.targetDate {
                                    Text(target.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Text("\(row.issues.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.vertical, 8)
                    .padding(.leading, 4)
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
                    .padding(.trailing, 8)
                }
            }
            .background(Color.primary.opacity(hoveringHeader ? 0.08 : 0.04))
            .onHover { hoveringHeader = $0 }

            if expanded {
                content()
            }
        }
    }
}
