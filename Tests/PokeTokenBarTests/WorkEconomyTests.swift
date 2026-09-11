import XCTest
@testable import PokeTokenBar

private struct WorkNoProvider: PokeProviding {
    func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
    func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
}

private final class ScriptedLinearHTTP: LinearHTTPClient, @unchecked Sendable {
    var responses: [(Int, Data)]
    var bodies: [Data] = []

    init(responses: [(Int, Data)]) {
        self.responses = responses
    }

    func postGraphQL(apiKey: String, body: Data) async throws -> (status: Int, data: Data) {
        bodies.append(body)
        XCTAssertFalse(responses.isEmpty, "unexpected extra Linear HTTP call")
        return responses.removeFirst()
    }
}

@MainActor
final class WorkRewardTests: XCTestCase {
    func testLinearEstimateOnly() {
        XCTAssertEqual(WorkReward.estimateFactor(nil), 1.0)
        XCTAssertEqual(WorkReward.estimateFactor(1), 1.0)
        XCTAssertEqual(WorkReward.estimateFactor(2), 1.25)
        XCTAssertEqual(WorkReward.estimateFactor(3), 1.5)
        XCTAssertEqual(WorkReward.estimateFactor(5), 2.0)
        XCTAssertEqual(WorkReward.estimateFactor(8), 3.0)
        XCTAssertEqual(WorkReward.estimateFactor(20), 4.0)
    }

    func testLinearPriorityOnly() {
        XCTAssertEqual(WorkReward.linearPriorityFactor(1), 1.5)
        XCTAssertEqual(WorkReward.linearPriorityFactor(2), 1.25)
        XCTAssertEqual(WorkReward.linearPriorityFactor(3), 1.0)
        XCTAssertEqual(WorkReward.linearPriorityFactor(4), 0.75)
        XCTAssertEqual(WorkReward.linearPriorityFactor(0), 1.0)
        XCTAssertEqual(WorkReward.linearPriorityFactor(nil), 1.0)
    }

    func testLinearEstimateAndPriorityTogether() {
        let item = WorkItem(
            source: .linear, remoteID: "a", title: "Ship",
            status: .completed, kind: .task, priority: 1, estimate: 5)
        let reward = WorkReward.forCompletion(item)
        XCTAssertEqual(reward.xp, Int((40_000.0 * 2.0 * 1.5).rounded()))
        XCTAssertEqual(reward.coins, Int((12.0 * 2.0 * 1.5).rounded()))
    }

    func testNilLinearDefaultsToBase() {
        let item = WorkItem(source: .linear, remoteID: "a", title: "Ship", status: .completed)
        XCTAssertEqual(WorkReward.forCompletion(item), WorkReward.linearBase)
    }

    func testReminderPriorityFactors() {
        XCTAssertEqual(WorkReward.reminderPriorityFactor(1), 1.4)
        XCTAssertEqual(WorkReward.reminderPriorityFactor(5), 1.0)
        XCTAssertEqual(WorkReward.reminderPriorityFactor(9), 0.75)
        XCTAssertEqual(WorkReward.reminderPriorityFactor(nil), 1.0)
        let high = WorkItem(source: .reminders, remoteID: "r", title: "Call",
                            status: .completed, kind: .task, priority: 1)
        XCTAssertEqual(WorkReward.forCompletion(high).xp, Int((20_000.0 * 1.4).rounded()))
    }

    func testCalendarAndNativeBases() {
        XCTAssertEqual(
            WorkReward.forCompletion(WorkItem(source: .appleCalendar, remoteID: "c", title: "Meet",
                                              status: .completed, kind: .event)),
            WorkReward.calendarBase)
        XCTAssertEqual(
            WorkReward.forCompletion(WorkItem(source: .googleCalendar, remoteID: "g", title: "Meet",
                                              status: .completed, kind: .event)),
            WorkReward.calendarBase)
        XCTAssertEqual(
            WorkReward.forCompletion(WorkItem(source: .native, remoteID: "n", title: "Task",
                                              status: .completed, kind: .task)),
            WorkReward.nativeTaskBase)
        XCTAssertEqual(
            WorkReward.forCompletion(WorkItem(source: .native, remoteID: "h", title: "Habit",
                                              status: .completed, kind: .habit)),
            WorkReward.habitBase)
        XCTAssertEqual(
            WorkReward.forCompletion(WorkItem(source: .native, remoteID: "g", title: "Goal",
                                              status: .completed, kind: .goal)),
            WorkReward.goalIncrement)
    }

    func testFocusIntervals() {
        XCTAssertEqual(WorkReward.forFocusIntervals(0), .zero)
        XCTAssertEqual(WorkReward.forFocusIntervals(2), Reward(xp: 16_000, coins: 4))
    }
}

final class CompletionLedgerTests: XCTestCase {
    func testFirstPollSeedsWithoutPay() {
        let outcome = CompletionLedger.evaluate(
            incomingKeys: ["linear:a", "linear:b"], alreadyCredited: [], seeded: false)
        XCTAssertTrue(outcome.newlyCredited.isEmpty)
        XCTAssertTrue(outcome.seeded)
        XCTAssertEqual(Set(outcome.creditedKeys), ["linear:a", "linear:b"])
    }

    func testSecondPollPaysNewKeys() {
        let seed = CompletionLedger.evaluate(
            incomingKeys: ["linear:a"], alreadyCredited: [], seeded: false)
        let next = CompletionLedger.evaluate(
            incomingKeys: ["linear:a", "linear:b"],
            alreadyCredited: seed.creditedKeys,
            seeded: true)
        XCTAssertEqual(next.newlyCredited, ["linear:b"])
    }

    func testDuplicateDoesNotPayTwice() {
        let first = CompletionLedger.evaluate(
            incomingKeys: ["native:1"], alreadyCredited: [], seeded: true)
        XCTAssertEqual(first.newlyCredited, ["native:1"])
        let second = CompletionLedger.evaluate(
            incomingKeys: ["native:1"], alreadyCredited: first.creditedKeys, seeded: true)
        XCTAssertTrue(second.newlyCredited.isEmpty)
    }

    func testSameRemoteIDDifferentSourcesAreDistinct() {
        let first = CompletionLedger.evaluate(
            incomingKeys: ["linear:1"], alreadyCredited: [], seeded: true)
        let second = CompletionLedger.evaluate(
            incomingKeys: ["reminders:1"], alreadyCredited: first.creditedKeys, seeded: true)
        XCTAssertEqual(second.newlyCredited, ["reminders:1"])
    }

    func testMigrateLegacyLinearIDs() {
        XCTAssertEqual(
            CompletionLedger.migrateLegacyLinearIDs(["issue-1", "linear:already"]),
            ["linear:issue-1", "linear:already"])
    }
}

@MainActor
final class WorkCompanionEconomyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func store() -> CompanionStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("work-econ-\(UUID().uuidString).json")
        return CompanionStore(provider: WorkNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1))
    }

    func testCreditPaysXPAndCoinsWithoutUsedSinceInstall() {
        let s = store()
        s.update(todayTokensByProvider: ["test": 0], todayDate: "d", monthTotal: 0,
                 burnTier: .idle, limitWarning: false, hasUsageData: true)
        let used = s.state.usedSinceInstall
        _ = s.credit(Reward(xp: 25_000, coins: 8))
        XCTAssertEqual(s.state.eggUsage, 25_000)
        XCTAssertEqual(s.state.coinsEarned, 8)
        XCTAssertEqual(s.state.usedSinceInstall, used)
        XCTAssertEqual(s.availableCoins, 8)
    }

    func testShopSpendsCoinsNotTokens() {
        let s = store()
        _ = s.credit(Reward(xp: 0, coins: RareCandy.price))
        XCTAssertTrue(s.buyRareCandy())
        XCTAssertEqual(s.state.coinsSpent, RareCandy.price)
        XCTAssertEqual(s.state.spentTokens, 0)
        XCTAssertEqual(s.availableCoins, 0)
        XCTAssertEqual(s.rareCandyCount, 1)
    }

    func testWorkLedgerFirstPollSeedsZeroThenPays() {
        let s = store()
        let first = WorkItem(source: .linear, remoteID: "a", title: "Old", status: .completed)
        let seed = s.creditWorkCompletions([first])
        XCTAssertTrue(seed.newlyCredited.isEmpty)
        XCTAssertEqual(s.state.coinsEarned, 0)
        XCTAssertEqual(s.state.eggUsage, 0)

        let second = WorkItem(source: .linear, remoteID: "b", title: "New", status: .completed, estimate: 1)
        let paid = s.creditWorkCompletions([first, second])
        XCTAssertEqual(paid.newlyCredited, [second.ledgerKey])
        XCTAssertEqual(s.state.coinsEarned, WorkReward.linearBase.coins)
        XCTAssertEqual(s.state.eggUsage, WorkReward.linearBase.xp)
    }

    func testForcePayDoesNotSeedHistoricalLinearDump() {
        let s = store()
        let native = WorkItem(source: .native, remoteID: "n1", title: "Task",
                              status: .completed, kind: .task)
        _ = s.creditWorkCompletions([native], forcePay: true)
        XCTAssertEqual(s.state.coinsEarned, WorkReward.nativeTaskBase.coins)
        XCTAssertFalse(s.state.workLedgerSeeded)

        let historical = WorkItem(source: .linear, remoteID: "old", title: "Old", status: .completed)
        let seed = s.creditWorkCompletions([historical])
        XCTAssertTrue(seed.newlyCredited.isEmpty)
        XCTAssertEqual(s.state.coinsEarned, WorkReward.nativeTaskBase.coins)
    }
}

@MainActor
final class NativeHabitTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func harness() -> (WorkHub, CompanionStore) {
        let workURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("work-\(UUID().uuidString).json")
        let stateURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("comp-\(UUID().uuidString).json")
        let hub = WorkHub(fileURL: workURL, apiKey: { nil })
        hub.remindersEnabled = false
        hub.appleCalendarEnabled = false
        hub.googleCalendarEnabled = false
        let companion = CompanionStore(
            provider: WorkNoProvider(), clock: { self.now }, fileURL: stateURL, rng: SeededRNG(seed: 1))
        return (hub, companion)
    }

    func testHabitPaysOncePerLocalDay() async {
        let (hub, companion) = harness()
        let item = hub.addNative(title: "Water", kind: .habit)
        await hub.complete(item, companion: companion)
        XCTAssertEqual(companion.state.coinsEarned, WorkReward.habitBase.coins)
        XCTAssertEqual(companion.state.eggUsage, WorkReward.habitBase.xp)

        let today = hub.items[0]
        XCTAssertEqual(today.displayStatus(today: hub.todayKey), .completed)
        await hub.complete(today, companion: companion)
        XCTAssertEqual(companion.state.coinsEarned, WorkReward.habitBase.coins, "same day does not pay twice")

        hub.todayKeyProvider = { "2099-12-31" }
        await hub.complete(hub.items[0], companion: companion)
        XCTAssertEqual(companion.state.coinsEarned, WorkReward.habitBase.coins * 2)
        XCTAssertEqual(hub.items[0].habitLastCompletedDay, "2099-12-31")
    }
}

@MainActor
final class FocusTimerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testTenMinuteFocusCreditsBothCurrencies() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("focus-\(UUID().uuidString).json")
        let companion = CompanionStore(
            provider: WorkNoProvider(), clock: { self.now }, fileURL: url, rng: SeededRNG(seed: 1))
        let timer = FocusTimer(duration: 25 * 60)
        let item = WorkItem(source: .native, remoteID: "t", title: "Focus", kind: .task)
        timer.assign(item)
        defer { timer.clear() }
        timer.start(now: now)
        let granted = timer.tick(now: now.addingTimeInterval(TimeOpenXP.awardIntervalSeconds), companion: companion)
        XCTAssertEqual(granted, 1)
        XCTAssertEqual(companion.state.coinsEarned, WorkReward.focusPerInterval.coins)
        XCTAssertEqual(companion.state.eggUsage, WorkReward.focusPerInterval.xp)
        XCTAssertEqual(companion.state.usedSinceInstall, 0)
        timer.clear()
    }
}

final class LinearCompleteMutationTests: XCTestCase {
    func testCompleteIssueLooksUpCompletedWorkflowStateThenMutates() async throws {
        let states = #"{"data":{"team":{"states":{"nodes":[{"id":"state-done","type":"completed"},{"id":"state-start","type":"started"}]}}}}"#
            .data(using: .utf8)!
        let update = #"{"data":{"issueUpdate":{"success":true}}}"#.data(using: .utf8)!
        let http = ScriptedLinearHTTP(responses: [(200, states), (200, update)])
        let client = LinearClient(http: http)
        try await client.completeIssue(apiKey: "lin_api_x", issueID: "issue-1", teamID: "team-1")
        XCTAssertEqual(http.bodies.count, 2)
        let statesBody = try XCTUnwrap(String(data: http.bodies[0], encoding: .utf8))
        XCTAssertTrue(statesBody.contains("states"))
        let mutationBody = try XCTUnwrap(String(data: http.bodies[1], encoding: .utf8))
        XCTAssertTrue(mutationBody.contains("issueUpdate"))
        XCTAssertTrue(mutationBody.contains("state-done"))
        XCTAssertTrue(mutationBody.contains("issue-1"))
    }

    func testDashboardMapsEstimatePriorityAndTeam() throws {
        let json = """
        {"data":{
          "completedRecent":{"nodes":[]},
          "inProgress":{"nodes":[
            {"id":"issue-3","identifier":"ENG-3","title":"High",
             "priority":2,"estimate":5,
             "updatedAt":"2026-09-06T09:00:00.000Z",
             "state":{"name":"In Progress","type":"started"},
             "team":{"id":"team-9","name":"Eng","key":"ENG"},
             "project":{"id":"proj-1","name":"App"}}
          ]}
        }}
        """.data(using: .utf8)!
        let dashboard = try LinearClient.parseIssueDashboard(json)
        let issue = try XCTUnwrap(dashboard.inProgress.first)
        XCTAssertEqual(issue.estimate, 5)
        XCTAssertEqual(issue.priority, 2)
        XCTAssertEqual(issue.teamID, "team-9")
        XCTAssertEqual(issue.projectID, "proj-1")
        let item = LinearWorkSource.item(from: issue, status: .inProgress, now: Date())
        XCTAssertEqual(item.estimate, 5)
        XCTAssertEqual(item.priority, 2)
        XCTAssertEqual(WorkReward.forCompletion(item).xp,
                       Int((40_000.0 * 2.0 * 1.25).rounded()))
    }
}

final class CalendarMappingTests: XCTestCase {
    func testGoogleParseHonorsExtendedPropertyAndOverlay() throws {
        let overlayURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cal-\(UUID().uuidString).json")
        let overlay = CalendarCompletionOverlay(fileURL: overlayURL)
        overlay.markCompleted(source: .googleCalendar, remoteID: "local-done", at: Date())
        let json = """
        {"items":[
          {"id":"evt-1","summary":"Standup","start":{"dateTime":"2026-09-11T01:00:00Z"},
           "extendedProperties":{"private":{"poketokenbarCompleted":"true"}}},
          {"id":"evt-2","summary":"Focus block","start":{"date":"2026-09-11"}},
          {"id":"local-done","summary":"Hidden locally","start":{"dateTime":"2026-09-11T02:00:00Z"}}
        ]}
        """.data(using: .utf8)!
        let items = try GoogleCalendarWorkSource.parseEvents(json, overlay: overlay, now: Date())
        XCTAssertEqual(items.first { $0.remoteID == "evt-1" }?.status, .completed)
        XCTAssertEqual(items.first { $0.remoteID == "evt-2" }?.status, .todo)
        XCTAssertEqual(items.first { $0.remoteID == "local-done" }?.status, .completed)
        XCTAssertEqual(WorkReward.forCompletion(items[0]).coins, WorkReward.calendarBase.coins)
    }

    func testAppleCalendarOverlayDoesNotNeedEventDeletion() {
        let overlayURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-cal-\(UUID().uuidString).json")
        let overlay = CalendarCompletionOverlay(fileURL: overlayURL)
        XCTAssertFalse(overlay.isCompleted(source: .appleCalendar, remoteID: "ek-1"))
        overlay.markCompleted(source: .appleCalendar, remoteID: "ek-1", at: Date())
        XCTAssertTrue(overlay.isCompleted(source: .appleCalendar, remoteID: "ek-1"))
        XCTAssertFalse(overlay.isCompleted(source: .googleCalendar, remoteID: "ek-1"))
    }

    func testGoogleTokenParse() throws {
        let data = #"{"access_token":"ya29.a","refresh_token":"1//r","expires_in":3600}"#.data(using: .utf8)!
        let tokens = try GoogleCalendarAuth.parseTokens(data)
        XCTAssertEqual(tokens.accessToken, "ya29.a")
        XCTAssertEqual(tokens.refreshToken, "1//r")
        XCTAssertGreaterThan(tokens.expiry, Date())
    }
}
