import EventKit
import Foundation

@MainActor
struct RemindersWorkSource: WorkSource {
    var sourceID: WorkSourceID { .reminders }
    var store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func fetch(now: Date) async throws -> [WorkItem] {
        try await requestAccess()
        let calendars = store.calendars(for: .reminder)
        let predicate = store.predicateForReminders(in: calendars)
        return try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { result in
                let items = (result ?? []).compactMap { Self.item(from: $0, now: now) }
                continuation.resume(returning: items)
            }
        }
    }

    func complete(_ item: WorkItem) async throws {
        guard item.source == .reminders else { throw WorkSourceError.unsupported }
        try await requestAccess()
        let calendars = store.calendars(for: .reminder)
        let predicate = store.predicateForReminders(in: calendars)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.fetchReminders(matching: predicate) { result in
                guard let reminder = (result ?? []).first(where: { $0.calendarItemIdentifier == item.remoteID }) else {
                    continuation.resume(throwing: WorkSourceError.remote("missing_reminder"))
                    return
                }
                reminder.isCompleted = true
                reminder.completionDate = Date()
                do {
                    try self.store.save(reminder, commit: true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated static func item(from reminder: EKReminder, now: Date) -> WorkItem? {
        let title = reminder.title ?? ""
        guard !title.isEmpty else { return nil }
        let priority = reminder.priority == 0 ? nil : reminder.priority
        return WorkItem(
            source: .reminders,
            remoteID: reminder.calendarItemIdentifier,
            title: title,
            notes: reminder.notes,
            status: reminder.isCompleted ? .completed : .todo,
            kind: .task,
            priority: priority,
            dueAt: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
            completedAt: reminder.completionDate,
            lastSyncedAt: now)
    }

    private func requestAccess() async throws {
        let granted = try await store.requestFullAccessToReminders()
        if !granted { throw WorkSourceError.permissionDenied }
    }
}
