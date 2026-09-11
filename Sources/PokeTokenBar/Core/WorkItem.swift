import Foundation

enum WorkSourceID: String, Codable, Sendable, CaseIterable, Hashable {
    case native
    case linear
    case reminders
    case appleCalendar
    case googleCalendar
}

enum WorkStatus: String, Codable, Sendable, Hashable {
    case todo
    case inProgress
    case completed
}

enum WorkKind: String, Codable, Sendable, Hashable {
    case task
    case habit
    case routine
    case goal
    case event
}

struct RoutineStep: Codable, Equatable, Sendable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var isDone: Bool

    init(id: UUID = UUID(), title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

/// Unified work item cached locally. Remote sources keep `remoteID` stable for the completion ledger.
struct WorkItem: Codable, Equatable, Sendable, Identifiable, Hashable {
    var id: UUID
    var source: WorkSourceID
    var remoteID: String
    var title: String
    var notes: String?
    var status: WorkStatus
    var kind: WorkKind
    var priority: Int?
    var estimate: Int?
    var dueAt: Date?
    var projectID: String?
    var projectName: String?
    var teamID: String?
    var url: URL?
    var completedAt: Date?
    var lastSyncedAt: Date?
    var subtasks: [RoutineStep]
    var goalTarget: Int?
    var goalProgress: Int?
    var habitLastCompletedDay: String?
    var goalBonusPaid: Bool

    init(
        id: UUID = UUID(),
        source: WorkSourceID,
        remoteID: String,
        title: String,
        notes: String? = nil,
        status: WorkStatus = .todo,
        kind: WorkKind = .task,
        priority: Int? = nil,
        estimate: Int? = nil,
        dueAt: Date? = nil,
        projectID: String? = nil,
        projectName: String? = nil,
        teamID: String? = nil,
        url: URL? = nil,
        completedAt: Date? = nil,
        lastSyncedAt: Date? = nil,
        subtasks: [RoutineStep] = [],
        goalTarget: Int? = nil,
        goalProgress: Int? = nil,
        habitLastCompletedDay: String? = nil,
        goalBonusPaid: Bool = false
    ) {
        self.id = id
        self.source = source
        self.remoteID = remoteID
        self.title = title
        self.notes = notes
        self.status = status
        self.kind = kind
        self.priority = priority
        self.estimate = estimate
        self.dueAt = dueAt
        self.projectID = projectID
        self.projectName = projectName
        self.teamID = teamID
        self.url = url
        self.completedAt = completedAt
        self.lastSyncedAt = lastSyncedAt
        self.subtasks = subtasks
        self.goalTarget = goalTarget
        self.goalProgress = goalProgress
        self.habitLastCompletedDay = habitLastCompletedDay
        self.goalBonusPaid = goalBonusPaid
    }

    var ledgerKey: String {
        if kind == .habit, let day = habitLastCompletedDay, !day.isEmpty {
            return CompletionLedger.key(source: source, remoteID: "\(remoteID)#\(day)")
        }
        return CompletionLedger.key(source: source, remoteID: remoteID)
    }

    func displayStatus(today: String) -> WorkStatus {
        if kind == .habit {
            return habitLastCompletedDay == today ? .completed : .todo
        }
        return status
    }

    var isGoalComplete: Bool {
        guard kind == .goal, let target = goalTarget else { return status == .completed }
        return (goalProgress ?? 0) >= target
    }
}

struct LinearProjectSummary: Equatable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
}

enum WorkSourceError: Error, Equatable {
    case notConfigured
    case permissionDenied
    case unsupported
    case remote(String)
}

@MainActor
protocol WorkSource {
    var sourceID: WorkSourceID { get }
    func fetch(now: Date) async throws -> [WorkItem]
    func complete(_ item: WorkItem) async throws
}
