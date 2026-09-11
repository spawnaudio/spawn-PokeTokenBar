import EventKit
import Foundation

/// Apple Calendar events for today. Completing is a local overlay — events are not deleted.
@MainActor
struct AppleCalendarWorkSource: WorkSource {
    var sourceID: WorkSourceID { .appleCalendar }
    var store: EKEventStore
    var overlay: CalendarCompletionOverlay

    init(store: EKEventStore = EKEventStore(), overlay: CalendarCompletionOverlay) {
        self.store = store
        self.overlay = overlay
    }

    func fetch(now: Date) async throws -> [WorkItem] {
        try await requestAccess()
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? now
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
        return events.map { event in
            let id = event.calendarItemIdentifier
            let completed = overlay.isCompleted(source: .appleCalendar, remoteID: id)
            return WorkItem(
                source: .appleCalendar,
                remoteID: id,
                title: event.title ?? "",
                notes: event.notes,
                status: completed ? .completed : .todo,
                kind: .event,
                dueAt: event.startDate,
                url: event.url,
                completedAt: completed ? overlay.completedAt(source: .appleCalendar, remoteID: id) : nil,
                lastSyncedAt: now)
        }
        .filter { !$0.title.isEmpty }
    }

    func complete(_ item: WorkItem) async throws {
        guard item.source == .appleCalendar else { throw WorkSourceError.unsupported }
        overlay.markCompleted(source: .appleCalendar, remoteID: item.remoteID, at: Date())
    }

    private func requestAccess() async throws {
        let granted = try await store.requestFullAccessToEvents()
        if !granted { throw WorkSourceError.permissionDenied }
    }
}

/// Local completion flags for calendar events (Apple overlay + Google cache fallback).
final class CalendarCompletionOverlay: @unchecked Sendable {
    private let url: URL
    private var completed: [String: Date]

    init(fileURL: URL? = nil) {
        url = fileURL ?? AppStatePaths.directory().appendingPathComponent("calendar-completions.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            completed = decoded
        } else {
            completed = [:]
        }
    }

    func isCompleted(source: WorkSourceID, remoteID: String) -> Bool {
        completed[CompletionLedger.key(source: source, remoteID: remoteID)] != nil
    }

    func completedAt(source: WorkSourceID, remoteID: String) -> Date? {
        completed[CompletionLedger.key(source: source, remoteID: remoteID)]
    }

    func markCompleted(source: WorkSourceID, remoteID: String, at date: Date) {
        completed[CompletionLedger.key(source: source, remoteID: remoteID)] = date
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(completed) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
