import Foundation
import Observation

/// Native tasks plus remote adapters. Companion only hears `Reward` via `creditWorkCompletions`.
@MainActor
@Observable
final class WorkHub {
    private(set) var items: [WorkItem] = []
    private(set) var linearProjects: [LinearProjectSummary] = []
    private(set) var projectIssues: [String: [WorkItem]] = [:]
    private(set) var lastError: String?
    private(set) var isRefreshing = false
    var remindersEnabled = UserDefaults.standard.bool(forKey: "remindersWorkEnabled") {
        didSet { UserDefaults.standard.set(remindersEnabled, forKey: "remindersWorkEnabled") }
    }
    var appleCalendarEnabled = UserDefaults.standard.bool(forKey: "appleCalendarWorkEnabled") {
        didSet { UserDefaults.standard.set(appleCalendarEnabled, forKey: "appleCalendarWorkEnabled") }
    }
    var googleCalendarEnabled = UserDefaults.standard.bool(forKey: "googleCalendarWorkEnabled") {
        didSet { UserDefaults.standard.set(googleCalendarEnabled, forKey: "googleCalendarWorkEnabled") }
    }

    private let fileURL: URL
    private let overlay: CalendarCompletionOverlay
    private var linearSource: LinearWorkSource
    private let remindersSource: RemindersWorkSource
    private let appleCalendarSource: AppleCalendarWorkSource
    private let googleCalendarSource: GoogleCalendarWorkSource
    private let linearClient: LinearClient
    private let apiKey: () -> String?
    var todayKeyProvider: () -> String = { LocalUsageReader.todayKey() }

    init(
        fileURL: URL? = nil,
        linearClient: LinearClient = LinearClient(),
        apiKey: @escaping () -> String? = { LinearAPIKeyStore().load()?.key },
        overlay: CalendarCompletionOverlay? = nil
    ) {
        self.fileURL = fileURL ?? AppStatePaths.directory().appendingPathComponent("work-items.json")
        self.overlay = overlay ?? CalendarCompletionOverlay()
        self.linearClient = linearClient
        self.apiKey = apiKey
        self.linearSource = LinearWorkSource(client: linearClient, apiKey: apiKey)
        self.remindersSource = RemindersWorkSource()
        self.appleCalendarSource = AppleCalendarWorkSource(overlay: self.overlay)
        self.googleCalendarSource = GoogleCalendarWorkSource(overlay: self.overlay)
        loadNative()
    }

    var todayKey: String { todayKeyProvider() }

    var completedTodayCount: Int {
        let today = todayKey
        return items.filter { item in
            if item.kind == .habit { return item.habitLastCompletedDay == today }
            guard item.displayStatus(today: today) == .completed, let done = item.completedAt else { return false }
            return Calendar.current.isDate(done, inSameDayAs: Date())
        }.count
    }

    func inbox(status: WorkStatus) -> [WorkItem] {
        let today = todayKey
        return items.filter { item in
            let shown = item.displayStatus(today: today)
            if shown == .completed, item.source == .appleCalendar || item.source == .googleCalendar {
                return false
            }
            return shown == status
        }
            .sorted { a, b in
                let da = a.dueAt ?? .distantFuture
                let db = b.dueAt ?? .distantFuture
                if da != db { return da < db }
                return a.title < b.title
            }
    }

    func nativeItems() -> [WorkItem] {
        items.filter { $0.source == .native }
    }

    @discardableResult
    func addNative(
        title: String,
        kind: WorkKind,
        notes: String? = nil,
        subtasks: [RoutineStep] = [],
        goalTarget: Int? = nil
    ) -> WorkItem {
        let item = WorkItem(
            source: .native,
            remoteID: UUID().uuidString,
            title: title,
            notes: notes,
            status: .todo,
            kind: kind,
            subtasks: subtasks,
            goalTarget: kind == .goal ? (goalTarget ?? 1) : nil,
            goalProgress: kind == .goal ? 0 : nil)
        items.append(item)
        saveNative()
        return item
    }

    func updateNative(_ item: WorkItem) {
        guard item.source == .native else { return }
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
            saveNative()
        }
    }

    func deleteNative(_ item: WorkItem) {
        items.removeAll { $0.id == item.id && $0.source == .native }
        saveNative()
    }

    func refreshAll(companion: CompanionStore) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var next = items.filter { $0.source == .native }
        var errors: [String] = []

        do {
            let remote = try await linearSource.fetch(now: Date())
            next.append(contentsOf: remote)
        } catch {
            if !(error is WorkSourceError && error as? WorkSourceError == .notConfigured) {
                errors.append("linear")
            }
        }
        if remindersEnabled {
            do { next.append(contentsOf: try await remindersSource.fetch(now: Date())) }
            catch { errors.append("reminders") }
        }
        if appleCalendarEnabled {
            do { next.append(contentsOf: try await appleCalendarSource.fetch(now: Date())) }
            catch { errors.append("appleCalendar") }
        }
        if googleCalendarEnabled {
            do { next.append(contentsOf: try await googleCalendarSource.fetch(now: Date())) }
            catch { errors.append("googleCalendar") }
        }

        items = mergePreservingNativeIDs(next)
        lastError = errors.isEmpty ? nil : errors.joined(separator: ",")
        let completed = items.filter { $0.displayStatus(today: todayKey) == .completed }
        _ = companion.creditWorkCompletions(completed)
        saveNative()
    }

    func complete(_ item: WorkItem, companion: CompanionStore) async {
        if item.source == .native, item.kind == .goal {
            incrementGoal(item, companion: companion)
            return
        }
        var working = item
        do {
            switch item.source {
            case .native:
                applyNativeComplete(&working)
            case .linear:
                try await linearSource.complete(item)
                working.status = .completed
                working.completedAt = Date()
            case .reminders:
                try await remindersSource.complete(item)
                working.status = .completed
                working.completedAt = Date()
            case .appleCalendar:
                try await appleCalendarSource.complete(item)
                working.status = .completed
                working.completedAt = Date()
            case .googleCalendar:
                try await googleCalendarSource.complete(item)
                working.status = .completed
                working.completedAt = Date()
            }
        } catch {
            lastError = "complete_failed"
            return
        }
        upsert(working)
        _ = companion.creditWorkCompletions([working], forcePay: true)
        saveNative()
    }

    func incrementGoal(_ item: WorkItem, companion: CompanionStore) {
        guard item.source == .native, item.kind == .goal else { return }
        var working = item
        working.goalProgress = (working.goalProgress ?? 0) + 1
        if working.isGoalComplete {
            working.status = .completed
            working.completedAt = Date()
        }
        upsert(working)
        _ = companion.creditWorkCompletions([
            WorkItem(
                id: working.id,
                source: .native,
                remoteID: "\(working.remoteID)#\(working.goalProgress ?? 0)",
                title: working.title,
                status: .completed,
                kind: .goal,
                completedAt: Date())
        ], forcePay: true)
        if working.isGoalComplete, !working.goalBonusPaid {
            working.goalBonusPaid = true
            upsert(working)
            _ = companion.credit(WorkReward.goalBonus)
        }
        saveNative()
    }

    func toggleRoutineStep(_ item: WorkItem, stepID: UUID, companion: CompanionStore) async {
        guard item.source == .native, item.kind == .routine else { return }
        var working = item
        guard let idx = working.subtasks.firstIndex(where: { $0.id == stepID }) else { return }
        working.subtasks[idx].isDone.toggle()
        if working.subtasks[idx].isDone {
            _ = companion.credit(WorkReward.nativeTaskBase)
        }
        if !working.subtasks.isEmpty, working.subtasks.allSatisfy(\.isDone) {
            await complete(working, companion: companion)
            return
        }
        upsert(working)
        saveNative()
    }

    func loadProjects() async {
        guard let key = apiKey() else { return }
        do {
            linearProjects = try await linearClient.fetchProjects(apiKey: key)
        } catch {
            lastError = "projects"
        }
    }

    func loadProjectIssues(_ projectID: String) async {
        guard let key = apiKey() else { return }
        do {
            let issues = try await linearClient.fetchProjectIssues(apiKey: key, projectID: projectID)
            projectIssues[projectID] = issues.map {
                LinearWorkSource.item(from: $0, status: $0.completedAt == nil ? .inProgress : .completed, now: Date())
            }
        } catch {
            lastError = "project_issues"
        }
    }

    private func applyNativeComplete(_ item: inout WorkItem) {
        let today = todayKey
        switch item.kind {
        case .habit:
            item.habitLastCompletedDay = today
            item.completedAt = Date()
        case .goal:
            item.goalProgress = (item.goalProgress ?? 0) + 1
            if item.isGoalComplete {
                item.status = .completed
                item.completedAt = Date()
            }
        default:
            item.status = .completed
            item.completedAt = Date()
        }
    }

    private func upsert(_ item: WorkItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id || ($0.source == item.source && $0.remoteID == item.remoteID) }) {
            items[idx] = item
        } else {
            items.append(item)
        }
    }

    private func mergePreservingNativeIDs(_ next: [WorkItem]) -> [WorkItem] {
        let natives = items.filter { $0.source == .native }
        var remotes = next.filter { $0.source != .native }
        for (index, remote) in remotes.enumerated() {
            if let existing = items.first(where: { $0.source == remote.source && $0.remoteID == remote.remoteID }) {
                remotes[index].id = existing.id
            }
        }
        return natives + remotes
    }

    private func loadNative() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([WorkItem].self, from: data)
        else { return }
        items = decoded.filter { $0.source == .native }
    }

    private func saveNative() {
        let natives = items.filter { $0.source == .native }
        if let data = try? JSONEncoder().encode(natives) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
