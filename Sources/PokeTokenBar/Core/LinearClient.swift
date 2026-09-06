import Foundation

/// Completed Linear issue eligible for companion XP.
struct LinearCompletedIssue: Equatable, Sendable, Identifiable {
    var id: String
    var identifier: String
    var title: String
    var completedAt: Date
}

/// Rich Linear issue metadata for UI surfaces.
struct LinearIssueSummary: Equatable, Sendable, Identifiable {
    var id: String
    var identifier: String
    var title: String
    var issueURL: URL?
    var priority: Int?
    var estimate: Int?
    var stateName: String?
    var stateType: String?
    var assigneeName: String?
    var assigneeEmail: String?
    var projectName: String?
    var teamName: String?
    var teamKey: String?
    var labelNames: [String]
    var createdAt: Date?
    var updatedAt: Date?
    var dueDate: Date?
    var completedAt: Date?
    var descriptionText: String?
}

struct LinearIssueDashboard: Equatable, Sendable {
    var completedRecent: [LinearIssueSummary]
    var inProgress: [LinearIssueSummary]
}

protocol LinearHTTPClient: Sendable {
    func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data)
}

struct URLSessionLinearClient: LinearHTTPClient {
    func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
        var request = URLRequest(url: URL(string: "https://api.linear.app/graphql")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        return (status, data)
    }
}

/// Fetches recently completed Linear issues. Injectable HTTP for tests.
struct LinearClient: Sendable {
    var http: any LinearHTTPClient = URLSessionLinearClient()

    /// Issues completed at or after `since` (ISO8601).
    func fetchCompletedIssues(apiKey: String, since: Date) async throws -> [LinearCompletedIssue] {
        let dashboard = try await fetchIssueDashboard(apiKey: apiKey, completedSince: since)
        return dashboard.completedRecent.compactMap { issue in
            guard let completedAt = issue.completedAt else { return nil }
            return LinearCompletedIssue(
                id: issue.id,
                identifier: issue.identifier,
                title: issue.title,
                completedAt: completedAt)
        }
    }

    /// Fetches issue panel data used by the popover.
    func fetchIssueDashboard(apiKey: String, completedSince: Date) async throws -> LinearIssueDashboard {
        let sinceISO = ISO8601DateFormatter().string(from: completedSince)
        let query = """
        query IssueDashboard($since: DateTime!) {
          completedRecent: issues(
            filter: { completedAt: { gte: $since } }
            first: 100
            orderBy: priority
          ) {
            nodes {
              id
              identifier
              title
              url
              description
              priority
              estimate
              state { name type }
              assignee { name email }
              project { name }
              team { name key }
              labels { nodes { name } }
              createdAt
              updatedAt
              dueDate
              completedAt
            }
          }
          inProgress: issues(first: 100, orderBy: priority) {
            nodes {
              id
              identifier
              title
              url
              description
              priority
              estimate
              state { name type }
              assignee { name email }
              project { name }
              team { name key }
              labels { nodes { name } }
              createdAt
              updatedAt
              dueDate
              completedAt
            }
          }
        }
        """
        let payload: [String: Any] = [
            "query": query,
            "variables": ["since": sinceISO]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (status, data): (Int, Data)
        do {
            (status, data) = try await http.postGraphQL(apiKey: apiKey, body: body)
        } catch {
            throw LinearAPIError.transport
        }
        guard (200..<300).contains(status) else { throw LinearAPIError.httpStatus(status) }
        return try Self.parseIssueDashboard(data)
    }

    static func parseIssueDashboard(_ data: Data) throws -> LinearIssueDashboard {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = root["data"] as? [String: Any],
              let completedPayload = dataObj["completedRecent"] as? [String: Any],
              let completedNodes = completedPayload["nodes"] as? [[String: Any]],
              let inProgressPayload = dataObj["inProgress"] as? [String: Any],
              let inProgressNodes = inProgressPayload["nodes"] as? [[String: Any]]
        else { throw LinearAPIError.decoding }

        let completed = try completedNodes.map(parseIssueSummary)
        let inProgress = try inProgressNodes
            .map(parseIssueSummary)
            .filter { $0.stateType?.lowercased() == "started" }

        return LinearIssueDashboard(
            completedRecent: sortedByPriority(completed),
            inProgress: sortedByPriority(inProgress))
    }

    static func sortedByPriority(_ issues: [LinearIssueSummary]) -> [LinearIssueSummary] {
        issues.sorted { a, b in
            let pa = prioritySortValue(a.priority)
            let pb = prioritySortValue(b.priority)
            if pa != pb { return pa < pb }
            let ua = a.updatedAt ?? .distantPast
            let ub = b.updatedAt ?? .distantPast
            if ua != ub { return ua > ub }
            return a.identifier < b.identifier
        }
    }

    private static func parseIssueSummary(_ node: [String: Any]) throws -> LinearIssueSummary {
        guard let id = node["id"] as? String, !id.isEmpty,
              let identifier = node["identifier"] as? String, !identifier.isEmpty,
              let title = node["title"] as? String, !title.isEmpty
        else { throw LinearAPIError.decoding }

        let state = node["state"] as? [String: Any]
        let assignee = node["assignee"] as? [String: Any]
        let project = node["project"] as? [String: Any]
        let team = node["team"] as? [String: Any]
        let labels = ((node["labels"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        let labelNames = labels.compactMap { $0["name"] as? String }

        return LinearIssueSummary(
            id: id,
            identifier: identifier,
            title: title,
            issueURL: (node["url"] as? String).flatMap(URL.init(string:)),
            priority: parseInt(node["priority"]),
            estimate: parseInt(node["estimate"]),
            stateName: state?["name"] as? String,
            stateType: state?["type"] as? String,
            assigneeName: assignee?["name"] as? String,
            assigneeEmail: assignee?["email"] as? String,
            projectName: project?["name"] as? String,
            teamName: team?["name"] as? String,
            teamKey: team?["key"] as? String,
            labelNames: labelNames,
            createdAt: parseDate(node["createdAt"]),
            updatedAt: parseDate(node["updatedAt"]),
            dueDate: parseDate(node["dueDate"]),
            completedAt: parseDate(node["completedAt"]),
            descriptionText: node["description"] as? String)
    }

    private static func prioritySortValue(_ priority: Int?) -> Int {
        guard let priority, priority > 0 else { return Int.max }
        return priority
    }

    private static func parseInt(_ raw: Any?) -> Int? {
        (raw as? Int) ?? (raw as? NSNumber)?.intValue
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        guard let raw = raw as? String, !raw.isEmpty else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plainISO = ISO8601DateFormatter()
        if let value = withFractional.date(from: raw) ?? plainISO.date(from: raw) {
            return value
        }
        let dayOnly = DateFormatter()
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        dayOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dayOnly.dateFormat = "yyyy-MM-dd"
        return dayOnly.date(from: raw)
    }

    /// Pure parser — unit-tested without network.
    static func parseCompletedIssues(_ data: Data) throws -> [LinearCompletedIssue] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = root["data"] as? [String: Any],
              let issues = dataObj["issues"] as? [String: Any],
              let nodes = issues["nodes"] as? [[String: Any]]
        else { throw LinearAPIError.decoding }

        return try nodes.compactMap { node in
            guard let id = node["id"] as? String, !id.isEmpty,
                  let identifier = node["identifier"] as? String, !identifier.isEmpty,
                  let title = node["title"] as? String, !title.isEmpty,
                  let completedAt = parseDate(node["completedAt"])
            else { throw LinearAPIError.decoding }
            return LinearCompletedIssue(
                id: id, identifier: identifier, title: title, completedAt: completedAt)
        }
    }
}

/// Pure reward math for Linear completions → companion XP.
enum LinearRewards {
    /// XP per newly completed issue (growth only — not `usedSinceInstall`).
    static let xpPerIssue = 2_000_000
    /// How far back to look for completions on each poll.
    static let lookbackDays = 14
    /// Cap persisted credited IDs so saves stay bounded.
    static let maxCreditedIDs = 500

    struct Outcome: Equatable {
        var xp: Int
        var creditedIDs: [String]
        /// True when this was the first successful poll (seed without XP).
        var seeded: Bool
        var newlyCredited: [LinearCompletedIssue]
    }

    /// Deduped grant. First successful poll (`seeded == false`) records IDs with 0 XP
    /// so already-done issues do not dump a backfill.
    static func evaluate(
        issues: [LinearCompletedIssue],
        alreadyCredited: [String],
        seeded: Bool
    ) -> Outcome {
        var credited = alreadyCredited
        var creditedSet = Set(alreadyCredited)
        let fresh = issues.filter { !creditedSet.contains($0.id) }
        guard seeded else {
            for issue in fresh {
                credited.append(issue.id)
                creditedSet.insert(issue.id)
            }
            credited = Array(credited.suffix(maxCreditedIDs))
            return Outcome(xp: 0, creditedIDs: credited, seeded: true, newlyCredited: [])
        }
        guard !fresh.isEmpty else {
            return Outcome(xp: 0, creditedIDs: credited, seeded: true, newlyCredited: [])
        }
        for issue in fresh {
            credited.append(issue.id)
        }
        credited = Array(credited.suffix(maxCreditedIDs))
        let xp = fresh.count * xpPerIssue
        return Outcome(xp: xp, creditedIDs: credited, seeded: true, newlyCredited: fresh)
    }

    static func mergedCreditedIDs(_ a: [String], _ b: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for id in a + b {
            if seen.insert(id).inserted { out.append(id) }
        }
        return Array(out.suffix(maxCreditedIDs))
    }
}
