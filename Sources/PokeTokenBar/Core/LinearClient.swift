import Foundation

/// Completed Linear issue eligible for companion XP.
struct LinearCompletedIssue: Equatable, Sendable, Identifiable {
    var id: String
    var identifier: String
    var title: String
    var completedAt: Date
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

    /// Issues completed at or after `since` (ISO8601), newest first, max 50.
    func fetchCompletedIssues(apiKey: String, since: Date) async throws -> [LinearCompletedIssue] {
        let sinceISO = ISO8601DateFormatter().string(from: since)
        let query = """
        query CompletedIssues($since: DateTime!) {
          issues(
            filter: { completedAt: { gte: $since } }
            first: 50
            orderBy: updatedAt
          ) {
            nodes { id identifier title completedAt }
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
        return try Self.parseCompletedIssues(data)
    }

    /// Pure parser — unit-tested without network.
    static func parseCompletedIssues(_ data: Data) throws -> [LinearCompletedIssue] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = root["data"] as? [String: Any],
              let issues = dataObj["issues"] as? [String: Any],
              let nodes = issues["nodes"] as? [[String: Any]]
        else { throw LinearAPIError.decoding }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()

        return try nodes.compactMap { node in
            guard let id = node["id"] as? String, !id.isEmpty,
                  let identifier = node["identifier"] as? String,
                  let title = node["title"] as? String,
                  let completedRaw = node["completedAt"] as? String
            else { throw LinearAPIError.decoding }
            let completedAt = formatter.date(from: completedRaw)
                ?? fallback.date(from: completedRaw)
            guard let completedAt else { throw LinearAPIError.decoding }
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
