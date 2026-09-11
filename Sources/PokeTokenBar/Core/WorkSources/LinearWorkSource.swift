import Foundation

@MainActor
struct LinearWorkSource: WorkSource {
    var sourceID: WorkSourceID { .linear }
    var client: LinearClient
    var apiKey: () -> String?

    func fetch(now: Date) async throws -> [WorkItem] {
        guard let key = apiKey() else { throw WorkSourceError.notConfigured }
        let since = Calendar.current.date(byAdding: .day, value: -LinearRewards.lookbackDays, to: now) ?? now
        let dashboard = try await client.fetchIssueDashboard(apiKey: key, completedSince: since)
        let inProgress = dashboard.inProgress.map { Self.item(from: $0, status: .inProgress, now: now) }
        let completed = dashboard.completedRecent.map { Self.item(from: $0, status: .completed, now: now) }
        return inProgress + completed
    }

    func complete(_ item: WorkItem) async throws {
        guard item.source == .linear else { throw WorkSourceError.unsupported }
        guard let key = apiKey() else { throw WorkSourceError.notConfigured }
        guard let teamID = item.teamID, !teamID.isEmpty else { throw WorkSourceError.remote("missing_team") }
        try await client.completeIssue(apiKey: key, issueID: item.remoteID, teamID: teamID)
    }

    nonisolated static func item(from issue: LinearIssueSummary, status: WorkStatus, now: Date) -> WorkItem {
        let resolved: WorkStatus
        if issue.completedAt != nil || issue.stateType?.lowercased() == "completed" {
            resolved = .completed
        } else {
            resolved = status
        }
        return WorkItem(
            source: .linear,
            remoteID: issue.id,
            title: "\(issue.identifier) \(issue.title)",
            notes: issue.descriptionText,
            status: resolved,
            kind: .task,
            priority: issue.priority,
            estimate: issue.estimate,
            dueAt: issue.dueDate,
            projectID: issue.projectID,
            projectName: issue.projectName,
            teamID: issue.teamID,
            url: issue.issueURL,
            completedAt: issue.completedAt,
            lastSyncedAt: now)
    }
}
