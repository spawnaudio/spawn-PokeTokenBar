import Foundation

@MainActor
struct GoogleCalendarWorkSource: WorkSource {
    var sourceID: WorkSourceID { .googleCalendar }
    var overlay: CalendarCompletionOverlay
    var session: URLSession = .shared

    func fetch(now: Date) async throws -> [WorkItem] {
        let token = try await validAccessToken()
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? now
        var comps = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        let iso = ISO8601DateFormatter()
        comps.queryItems = [
            URLQueryItem(name: "timeMin", value: iso.string(from: start)),
            URLQueryItem(name: "timeMax", value: iso.string(from: end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "50"),
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WorkSourceError.remote("http")
        }
        return try Self.parseEvents(data, overlay: overlay, now: now)
    }

    func complete(_ item: WorkItem) async throws {
        guard item.source == .googleCalendar else { throw WorkSourceError.unsupported }
        overlay.markCompleted(source: .googleCalendar, remoteID: item.remoteID, at: Date())
        let token = try await validAccessToken()
        guard let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events/\(item.remoteID)") else {
            throw WorkSourceError.remote("bad_id")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "extendedProperties": [
                "private": ["poketokenbarCompleted": "true"]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WorkSourceError.remote("patch")
        }
    }

    nonisolated static func parseEvents(_ data: Data, overlay: CalendarCompletionOverlay, now: Date) throws -> [WorkItem] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]]
        else { throw WorkSourceError.remote("decode") }
        return items.compactMap { node -> WorkItem? in
            guard let id = node["id"] as? String, !id.isEmpty,
                  let title = node["summary"] as? String, !title.isEmpty
            else { return nil }
            let privateProps = ((node["extendedProperties"] as? [String: Any])?["private"] as? [String: Any])
            let remoteDone = (privateProps?["poketokenbarCompleted"] as? String) == "true"
            let localDone = overlay.isCompleted(source: .googleCalendar, remoteID: id)
            let done = remoteDone || localDone
            let start = ((node["start"] as? [String: Any])?["dateTime"] as? String)
                ?? ((node["start"] as? [String: Any])?["date"] as? String)
            return WorkItem(
                source: .googleCalendar,
                remoteID: id,
                title: title,
                notes: node["description"] as? String,
                status: done ? .completed : .todo,
                kind: .event,
                dueAt: parseGoogleDate(start),
                url: (node["htmlLink"] as? String).flatMap(URL.init(string:)),
                completedAt: done ? overlay.completedAt(source: .googleCalendar, remoteID: id) : nil,
                lastSyncedAt: now)
        }
    }

    private func validAccessToken() async throws -> String {
        guard var tokens = GoogleTokenStore.load() else { throw WorkSourceError.notConfigured }
        if tokens.expiry > Date() { return tokens.accessToken }
        tokens = try await GoogleCalendarAuth.refresh(tokens)
        GoogleTokenStore.save(tokens)
        return tokens.accessToken
    }

    nonisolated private static func parseGoogleDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        if let value = withFractional.date(from: raw) ?? plain.date(from: raw) { return value }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(secondsFromGMT: 0)
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: raw)
    }
}
