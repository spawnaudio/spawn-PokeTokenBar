import XCTest
@testable import PokeTokenBar

final class LinearRewardsTests: XCTestCase {
    private final class StubLinearHTTPClient: LinearHTTPClient, @unchecked Sendable {
        var status: Int
        var data: Data
        var shouldThrow = false
        var lastBody: Data?

        init(status: Int, data: Data) {
            self.status = status
            self.data = data
        }

        func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
            lastBody = body
            if shouldThrow { throw URLError(.cannotConnectToHost) }
            return (status, data)
        }
    }

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
        XCTAssertEqual(merged.count, 400)
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

    func testParseIssueDashboardSortsByPriority() throws {
        let json = """
        {"data":{
          "completedRecent":{"nodes":[
            {"id":"issue-2","identifier":"ENG-2","title":"Later",
             "priority":3,"updatedAt":"2026-09-06T12:00:00.000Z",
             "completedAt":"2026-09-06T12:00:00.000Z"},
            {"id":"issue-1","identifier":"ENG-1","title":"Urgent",
             "priority":1,"updatedAt":"2026-09-06T11:00:00.000Z",
             "completedAt":"2026-09-06T11:00:00.000Z"}
          ]},
          "inProgress":{"nodes":[
            {"id":"issue-4","identifier":"ENG-4","title":"No priority",
             "priority":0,"updatedAt":"2026-09-06T10:00:00.000Z",
             "state":{"name":"In Progress","type":"started"}},
            {"id":"issue-3","identifier":"ENG-3","title":"High",
             "priority":2,"updatedAt":"2026-09-06T09:00:00.000Z",
             "state":{"name":"In Progress","type":"started"},
             "labels":{"nodes":[{"name":"backend"}]},
             "dueDate":"2026-09-07"}
          ]}
        }}
        """.data(using: .utf8)!

        let dashboard = try LinearClient.parseIssueDashboard(json)
        XCTAssertEqual(dashboard.completedRecent.map(\.id), ["issue-1", "issue-2"])
        XCTAssertEqual(dashboard.inProgress.map(\.id), ["issue-3", "issue-4"])
        XCTAssertEqual(dashboard.inProgress.first?.stateType, "started")
        XCTAssertEqual(dashboard.inProgress.first?.labelNames, ["backend"])
        XCTAssertNotNil(dashboard.inProgress.first?.dueDate)
    }

    func testNormalizeRejectsNonLinearKeys() {
        XCTAssertThrowsError(try LinearAPIKeyStore.normalize("sk-ant-not-linear"))
        XCTAssertNoThrow(try LinearAPIKeyStore.normalize("lin_api_" + String(repeating: "x", count: 40)))
    }

    func testValidateAPIKeyUsesViewerProbe() async throws {
        let data = #"{"data":{"viewer":{"id":"user-1"}}}"#.data(using: .utf8)!
        let http = StubLinearHTTPClient(status: 200, data: data)
        let client = LinearClient(http: http)

        try await client.validateAPIKey(
            apiKey: "lin_api_" + String(repeating: "x", count: 40))

        let sentBody = try XCTUnwrap(http.lastBody)
        let bodyText = try XCTUnwrap(String(data: sentBody, encoding: .utf8))
        XCTAssertTrue(bodyText.contains("viewer"))
        XCTAssertFalse(bodyText.contains("completedRecent"))
    }

    func testValidateAPIKeyRejectsUnauthorizedStatus() async {
        let data = #"{"errors":[{"message":"Unauthorized"}]}"#.data(using: .utf8)!
        let client = LinearClient(http: StubLinearHTTPClient(status: 401, data: data))

        do {
            try await client.validateAPIKey(apiKey: "lin_api_" + String(repeating: "x", count: 40))
            XCTFail("Expected unauthorized error")
        } catch {
            XCTAssertEqual(error as? LinearAPIError, .unauthorized)
        }
    }

    func testValidateAPIKeyRejectsUnauthorizedGraphQLError() async {
        let data = #"{"errors":[{"message":"Invalid auth token"}]}"#.data(using: .utf8)!
        let client = LinearClient(http: StubLinearHTTPClient(status: 200, data: data))

        do {
            try await client.validateAPIKey(apiKey: "lin_api_" + String(repeating: "x", count: 40))
            XCTFail("Expected unauthorized error")
        } catch {
            XCTAssertEqual(error as? LinearAPIError, .unauthorized)
        }
    }

    func testFetchIssueDashboardDoesNotUseInvalidPriorityOrderBy() async throws {
        let fixture = """
        {"data":{
          "completedRecent":{"nodes":[
            {"id":"issue-1","identifier":"ENG-1","title":"Done",
             "priority":2,"updatedAt":"2026-09-06T12:00:00.000Z",
             "completedAt":"2026-09-06T12:00:00.000Z"}
          ]},
          "inProgress":{"nodes":[
            {"id":"issue-2","identifier":"ENG-2","title":"Doing",
             "priority":1,"updatedAt":"2026-09-06T10:00:00.000Z",
             "state":{"name":"In Progress","type":"started"}}
          ]}
        }}
        """.data(using: .utf8)!
        let http = StubLinearHTTPClient(status: 200, data: fixture)
        let client = LinearClient(http: http)

        _ = try await client.fetchIssueDashboard(
            apiKey: "lin_api_" + String(repeating: "x", count: 40),
            completedSince: Date(timeIntervalSince1970: 1_700_000_000))

        let sentBody = try XCTUnwrap(http.lastBody)
        let bodyText = try XCTUnwrap(String(data: sentBody, encoding: .utf8))
        XCTAssertFalse(bodyText.contains("orderBy: priority"))
        XCTAssertTrue(bodyText.contains("DateTimeOrDuration!"))
    }

    func testLinearValidationRejectsOnlyAuthFailures() {
        XCTAssertTrue(UsageStore.shouldRejectLinearAPIKeyValidation(LinearAPIError.unauthorized))
        XCTAssertTrue(UsageStore.shouldRejectLinearAPIKeyValidation(LinearAPIError.httpStatus(403)))
        XCTAssertFalse(UsageStore.shouldRejectLinearAPIKeyValidation(LinearAPIError.transport))
        XCTAssertFalse(UsageStore.shouldRejectLinearAPIKeyValidation(LinearAPIError.httpStatus(500)))
    }
}
