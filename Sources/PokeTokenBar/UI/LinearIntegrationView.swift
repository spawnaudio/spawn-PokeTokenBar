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

    var symbol: String {
        switch self {
        case .issues: return LinearChromeSymbol.issue
        case .projects: return LinearChromeSymbol.project
        case .initiatives: return LinearChromeSymbol.initiative
        }
    }
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
                .buttonStyle(.borderless)
                .help(l.refreshNow)
                .disabled(!store.linearIntegrationEnabled || !store.linearAPIKeyConfigured || store.isRefreshingLinearIssues)
            }

            HStack {
                Image(systemName: selectedRoot.symbol)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Picker("", selection: $selectedRoot) {
                    Text(l.linearIssuesTab).tag(LinearRootTab.issues)
                    Text(l.linearProjectsTab).tag(LinearRootTab.projects)
                    Text(l.linearInitiativesTab).tag(LinearRootTab.initiatives)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if !store.linearIntegrationEnabled || !store.linearAPIKeyConfigured {
                Text(l.linearIssuesNeedsSetup)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if selectedRoot == .issues {
                    Picker("", selection: $selectedIssuesTab) {
                        Text(l.linearInProgressTab).tag(LinearIssuesTab.inProgress)
                        Text(l.linearCompletedTodayTab).tag(LinearIssuesTab.completedToday)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } else if selectedRoot == .projects {
                    Picker("", selection: $selectedProjectsTab) {
                        Text(l.linearInProgressTab).tag(LinearProjectsTab.inProgress)
                        Text(l.linearProductionTab).tag(LinearProjectsTab.production)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } else if selectedRoot == .initiatives {
                    Picker("", selection: $selectedInitiativesTab) {
                        Text(l.linearActiveTab).tag(LinearInitiativesTab.active)
                        Text(l.linearPlannedTab).tag(LinearInitiativesTab.planned)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
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
        .frame(height: 520)
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
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleIssues) { issue in
                        issueCard(issue)
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
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(items) { row in
                            LinearFoldableRow(row: row, openHelp: openHelp) {
                                if row.issues.isEmpty {
                                    Text(l.linearContainerEmptyIssues)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 4)
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(row.issues) { issue in
                                            issueCard(issue)
                                        }
                                    }
                                    .padding(.top, 6)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func issueCard(_ issue: LinearIssueSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                statusDot(issue.stateType)
                if let name = issue.stateName, !name.isEmpty {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                LinearIssueIDButton(identifier: issue.identifier, url: issue.issueURL)
                Spacer(minLength: 4)
                LinearIssueStatusPicker(issue: issue)
                LinearFocusButton(issue: issue, openDeskOnPin: false) {
                    nav.showFocus()
                }
            }

            Text(issue.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            denseMeta(issue)

            if let text = issue.descriptionText, !text.isEmpty {
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            LinearIssueCompletionStats(issue: issue)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func denseMeta(_ issue: LinearIssueSummary) -> some View {
        let chips = metaChips(issue)
        if !chips.isEmpty {
            Text(chips.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func metaChips(_ issue: LinearIssueSummary) -> [String] {
        var chips: [String] = []
        if issue.priority != nil {
            chips.append(l.linearPriority(issue.priority))
        }
        if let key = issue.teamKey, !key.isEmpty {
            chips.append(key)
        }
        if let project = issue.projectName, !project.isEmpty {
            chips.append(project)
        }
        if let assignee = issue.assigneeName, !assignee.isEmpty {
            chips.append(assignee)
        }
        if !issue.labelNames.isEmpty {
            chips.append(issue.labelNames.prefix(3).joined(separator: ", "))
        }
        if let estimate = issue.estimate {
            chips.append("E\(estimate)")
        }
        if let due = issue.dueDate {
            chips.append(shortDate(due))
        }
        return chips
    }

    private func statusDot(_ type: String?) -> some View {
        Circle()
            .fill(statusColor(type))
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }

    private func statusColor(_ type: String?) -> Color {
        switch (type ?? "").lowercased() {
        case "completed": return .green
        case "started": return .yellow
        case "canceled", "cancelled": return .secondary
        default: return .blue
        }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

/// Shared unfold row for Linear projects and initiatives.
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
                    .padding(8)
                    .contentShape(Rectangle())
                    .background(
                        hoveringHeader
                            ? Color.primary.opacity(0.08)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
                .onHover { hoveringHeader = $0 }

                if let url = row.url {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help(openHelp)
                    .padding(.trailing, 8)
                }
            }

            if expanded {
                content()
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
