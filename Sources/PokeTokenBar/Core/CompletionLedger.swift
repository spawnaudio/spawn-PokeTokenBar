import Foundation

/// Dedupe + no-backfill ledger for work completions. First successful poll seeds IDs with no pay.
enum CompletionLedger {
    static let maxCreditedKeys = 500

    struct Outcome: Equatable, Sendable {
        var newlyCredited: [String]
        var creditedKeys: [String]
        var seeded: Bool
    }

    static func key(source: WorkSourceID, remoteID: String) -> String {
        "\(source.rawValue):\(remoteID)"
    }

    static func evaluate(incomingKeys: [String], alreadyCredited: [String], seeded: Bool) -> Outcome {
        var credited = alreadyCredited
        var creditedSet = Set(alreadyCredited)
        var seenIncoming = Set<String>()
        let uniqueIncoming = incomingKeys.filter { seenIncoming.insert($0).inserted }
        let fresh = uniqueIncoming.filter { !creditedSet.contains($0) }
        guard seeded else {
            for key in fresh {
                credited.append(key)
                creditedSet.insert(key)
            }
            credited = Array(credited.suffix(maxCreditedKeys))
            return Outcome(newlyCredited: [], creditedKeys: credited, seeded: true)
        }
        guard !fresh.isEmpty else {
            return Outcome(newlyCredited: [], creditedKeys: credited, seeded: true)
        }
        for key in fresh {
            credited.append(key)
        }
        credited = Array(credited.suffix(maxCreditedKeys))
        return Outcome(newlyCredited: fresh, creditedKeys: credited, seeded: true)
    }

    static func merged(_ a: [String], _ b: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for key in a + b {
            if seen.insert(key).inserted { out.append(key) }
        }
        return Array(out.suffix(maxCreditedKeys))
    }

    /// Upgrade legacy Linear-only IDs (`issue-1`) into namespaced keys (`linear:issue-1`).
    static func migrateLegacyLinearIDs(_ ids: [String]) -> [String] {
        ids.map { id in
            if id.contains(":") { return id }
            return key(source: .linear, remoteID: id)
        }
    }
}
