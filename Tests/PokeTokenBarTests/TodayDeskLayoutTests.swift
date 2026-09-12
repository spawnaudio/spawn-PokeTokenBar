import XCTest
@testable import PokeTokenBar

final class TodayDeskLayoutTests: XCTestCase {
    func testTodayIdentifiersStayOnLaunchWindowPolicy() {
        XCTAssertEqual(LaunchWindowPolicy.todayDeskIdentifier, "PokeTokenBar.TodayDesk")
        XCTAssertEqual(LaunchWindowPolicy.todayDeskAutosaveName, "PokeTokenBarTodayDesk")
        XCTAssertFalse(LaunchWindowPolicy.isSwiftUISettingsPlaceholder(
            identifier: LaunchWindowPolicy.todayDeskIdentifier,
            autosaveName: LaunchWindowPolicy.todayDeskAutosaveName))
    }

    func testDefaultSizeIsWideEnoughForDualSidebars() {
        XCTAssertEqual(TodayDeskMetrics.defaultWidth, 920)
        XCTAssertEqual(TodayDeskMetrics.defaultHeight, 680)
        XCTAssertGreaterThanOrEqual(TodayDeskMetrics.leftSidebarWidth, 200)
        XCTAssertLessThanOrEqual(TodayDeskMetrics.leftSidebarWidth, 220)
        XCTAssertGreaterThanOrEqual(TodayDeskMetrics.rightSidebarWidth, 220)
        XCTAssertLessThanOrEqual(TodayDeskMetrics.rightSidebarWidth, 240)
        XCTAssertGreaterThanOrEqual(TodayDeskMetrics.minWidth, TodayDeskMetrics.columnsWidth)
        XCTAssertTrue(TodayDeskMetrics.fitsThreeColumns(TodayDeskMetrics.minWidth))
        XCTAssertTrue(TodayDeskMetrics.fitsThreeColumns(TodayDeskMetrics.defaultWidth))
        XCTAssertFalse(TodayDeskMetrics.fitsThreeColumns(440))
    }

    func testInspectorOmitsEmptyMetadata() {
        let issue = sampleIssue(
            stateName: nil,
            teamName: nil,
            teamKey: nil,
            projectName: nil,
            assigneeName: nil,
            labelNames: [],
            estimate: nil,
            dueDate: nil)
        XCTAssertTrue(LinearIssueInspector.fields(for: issue, dueText: { _ in "Sep 7" }).isEmpty)
    }

    func testInspectorListsFetchedMetadataInOrder() {
        let due = Date(timeIntervalSince1970: 1_778_000_000)
        let issue = sampleIssue(
            stateName: "In Progress",
            stateType: "started",
            teamName: "Engineering",
            teamKey: "ENG",
            projectName: "Auth",
            assigneeName: "Ada",
            labelNames: ["focus", "v3"],
            estimate: 3,
            dueDate: due)
        let fields = LinearIssueInspector.fields(for: issue, dueText: { _ in "Sep 7" })
        XCTAssertEqual(fields.map(\.kind), [
            .status, .team, .project, .assignee, .labels, .estimate, .due,
        ])
        XCTAssertEqual(fields[0].value, "In Progress")
        XCTAssertEqual(fields[0].stateType, "started")
        XCTAssertEqual(fields[1].value, "ENG · Engineering")
        XCTAssertEqual(fields[2].value, "Auth")
        XCTAssertEqual(fields[3].value, "Ada")
        XCTAssertEqual(fields[4].value, "focus, v3")
        XCTAssertEqual(fields[5].value, "3")
        XCTAssertEqual(fields[6].value, "Sep 7")
    }

    func testForfeitLogUsesDestructiveTint() {
        let pinned = FocusPinnedIssue(sampleIssue())
        let forfeit = FocusLogEntry.forfeit(day: "2026-09-12", issue: pinned, leaveInProgressXP: 1_000_000)
        let session = FocusLogEntry.session(
            day: "2026-09-12",
            issue: pinned,
            startedAt: Date(timeIntervalSince1970: 1),
            duration: 60,
            overtime: 0)
        let checkIn = FocusLogEntry.checkIn(
            day: "2026-09-12",
            issue: pinned,
            answer: .yes,
            notePosted: false)
        let note = FocusLogEntry.note(day: "2026-09-12", issue: pinned, text: "shipped")
        XCTAssertTrue(forfeit.usesDestructiveTint)
        XCTAssertFalse(session.usesDestructiveTint)
        XCTAssertFalse(checkIn.usesDestructiveTint)
        XCTAssertFalse(note.usesDestructiveTint)
    }

    private func sampleIssue(
        stateName: String? = "In Progress",
        stateType: String? = "started",
        teamName: String? = "Eng",
        teamKey: String? = "ENG",
        projectName: String? = nil,
        assigneeName: String? = nil,
        labelNames: [String] = [],
        estimate: Int? = nil,
        dueDate: Date? = nil
    ) -> LinearIssueSummary {
        LinearIssueSummary(
            id: "issue-1",
            identifier: "ENG-142",
            title: "Ship login",
            issueURL: URL(string: "https://linear.app/issue/ENG-142"),
            priority: 2,
            estimate: estimate,
            stateId: "start",
            stateName: stateName,
            stateType: stateType,
            assigneeName: assigneeName,
            assigneeEmail: nil,
            projectName: projectName,
            teamName: teamName,
            teamKey: teamKey,
            teamID: "team-1",
            teamStates: [],
            completedStateId: "done",
            labelNames: labelNames,
            createdAt: nil,
            updatedAt: nil,
            dueDate: dueDate,
            completedAt: nil,
            descriptionText: nil)
    }
}
