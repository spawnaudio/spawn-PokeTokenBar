import XCTest
@testable import PokeTokenBar

final class LinearRewardsTests: XCTestCase {
    private func issue(_ id: String, at offset: TimeInterval = 0) -> LinearCompletedIssue {
        LinearCompletedIssue(
            id: id,
            identifier: "ENG-\(id)",
            title: "Done \(id)",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000 + offset))
    }

    func testFirstPollSeedsWithoutXP() {
        let outcome = LinearRewards.evaluate(
            issues: [issue("a"), issue("b")],
            alreadyCredited: [],
            seeded: false)
        XCTAssertEqual(outcome.xp, 0)
        XCTAssertTrue(outcome.seeded)
        XCTAssertEqual(Set(outcome.creditedIDs), ["a", "b"])
        XCTAssertTrue(outcome.newlyCredited.isEmpty)
    }

    func testSubsequentPollAwardsOnlyNewIssues() {
        let seeded = LinearRewards.evaluate(
            issues: [issue("a")], alreadyCredited: [], seeded: false)
        let next = LinearRewards.evaluate(
            issues: [issue("a"), issue("b")],
            alreadyCredited: seeded.creditedIDs,
            seeded: true)
        XCTAssertEqual(next.xp, LinearRewards.xpPerIssue)
        XCTAssertEqual(next.newlyCredited.map(\.id), ["b"])
        XCTAssertEqual(Set(next.creditedIDs), ["a", "b"])
    }

    func testDuplicateIDsAcrossPollsDoNotReAward() {
        let first = LinearRewards.evaluate(
            issues: [issue("a")], alreadyCredited: [], seeded: true)
        XCTAssertEqual(first.xp, LinearRewards.xpPerIssue)
        let second = LinearRewards.evaluate(
            issues: [issue("a")], alreadyCredited: first.creditedIDs, seeded: true)
        XCTAssertEqual(second.xp, 0)
    }

    func testMergedCreditedIDsUnionsAndCaps() {
        let a = (0..<300).map(String.init)
        let b = (200..<400).map(String.init)
        let merged = LinearRewards.mergedCreditedIDs(a, b)
        XCTAssertEqual(merged.count, LinearRewards.maxCreditedIDs)
        XCTAssertTrue(Set(merged).isSubset(of: Set(a + b)))
    }

    func testParseCompletedIssuesFromGraphQLFixture() throws {
        let json = """
        {"data":{"issues":{"nodes":[
          {"id":"issue-1","identifier":"ENG-1","title":"Ship it",
           "completedAt":"2026-09-06T12:00:00.000Z"}
        ]}}}
        """.data(using: .utf8)!
        let issues = try LinearClient.parseCompletedIssues(json)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].id, "issue-1")
        XCTAssertEqual(issues[0].identifier, "ENG-1")
    }

    func testNormalizeRejectsNonLinearKeys() {
        XCTAssertThrowsError(try LinearAPIKeyStore.normalize("sk-ant-not-linear"))
        XCTAssertNoThrow(try LinearAPIKeyStore.normalize("lin_api_" + String(repeating: "x", count: 40)))
    }
}
