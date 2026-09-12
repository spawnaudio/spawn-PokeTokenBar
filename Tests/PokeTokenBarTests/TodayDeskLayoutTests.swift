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

    func testSidebarKeysAreIndependentOfWindowAutosave() {
        XCTAssertEqual(TodayDeskLayout.leftWidthKey, "todayDeskLeftWidth")
        XCTAssertEqual(TodayDeskLayout.rightWidthKey, "todayDeskRightWidth")
        XCTAssertEqual(TodayDeskLayout.leftCollapsedKey, "todayDeskLeftCollapsed")
        XCTAssertEqual(TodayDeskLayout.rightCollapsedKey, "todayDeskRightCollapsed")
        XCTAssertNotEqual(TodayDeskLayout.leftWidthKey, LaunchWindowPolicy.todayDeskAutosaveName)
        XCTAssertNotEqual(TodayDeskLayout.rightWidthKey, LaunchWindowPolicy.todayDeskAutosaveName)
    }

    func testCollapsedSidebarsHaveZeroDisplayWidthAndKeepPreferred() {
        let layout = TodayDeskLayout(
            leftWidth: TodayDeskMetrics.leftSidebarWidth,
            rightWidth: TodayDeskMetrics.rightSidebarWidth,
            leftCollapsed: true,
            rightCollapsed: true)
        let container: CGFloat = 888
        let resolved = layout.resolved(containerWidth: container)
        XCTAssertEqual(resolved.leftWidth, 0)
        XCTAssertEqual(resolved.rightWidth, 0)
        XCTAssertEqual(layout.leftWidth, TodayDeskMetrics.leftSidebarWidth)
        XCTAssertEqual(layout.rightWidth, TodayDeskMetrics.rightSidebarWidth)
        XCTAssertEqual(
            resolved.centerWidth,
            container - TodayDeskMetrics.splitterWidth * 2,
            accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(resolved.centerWidth, TodayDeskMetrics.minCenterWidth)
    }

    func testExpandedSidebarsUsePreferredWidthsInsideDefaultWindow() {
        let layout = TodayDeskLayout.default
        let resolved = layout.resolved(containerWidth: 888)
        XCTAssertEqual(resolved.leftWidth, TodayDeskMetrics.leftSidebarWidth)
        XCTAssertEqual(resolved.rightWidth, TodayDeskMetrics.rightSidebarWidth)
        XCTAssertGreaterThanOrEqual(resolved.centerWidth, TodayDeskMetrics.minCenterWidth)
        XCTAssertEqual(
            resolved.leftWidth + resolved.rightWidth + resolved.centerWidth + TodayDeskMetrics.splitterWidth * 2,
            888,
            accuracy: 0.001)
    }

    func testLeftCollapsedOnlyGivesCenterTheLeftSpace() {
        let expanded = TodayDeskLayout.default.resolved(containerWidth: 888)
        let collapsedLeft = TodayDeskLayout.default.togglingLeft().resolved(containerWidth: 888)
        XCTAssertEqual(collapsedLeft.leftWidth, 0)
        XCTAssertEqual(collapsedLeft.rightWidth, TodayDeskMetrics.rightSidebarWidth)
        XCTAssertEqual(
            collapsedLeft.centerWidth,
            expanded.centerWidth + TodayDeskMetrics.leftSidebarWidth,
            accuracy: 0.001)
    }

    func testRightCollapsedOnlyGivesCenterTheRightSpace() {
        let expanded = TodayDeskLayout.default.resolved(containerWidth: 888)
        let collapsedRight = TodayDeskLayout.default.togglingRight().resolved(containerWidth: 888)
        XCTAssertEqual(collapsedRight.rightWidth, 0)
        XCTAssertEqual(collapsedRight.leftWidth, TodayDeskMetrics.leftSidebarWidth)
        XCTAssertEqual(
            collapsedRight.centerWidth,
            expanded.centerWidth + TodayDeskMetrics.rightSidebarWidth,
            accuracy: 0.001)
    }

    func testSidebarCapUsesFortyPercentWhenThatIsBelowMax() {
        XCTAssertEqual(TodayDeskLayout.sidebarCap(containerWidth: 500), 200, accuracy: 0.001)
        XCTAssertEqual(TodayDeskLayout.sidebarCap(containerWidth: 2000), TodayDeskMetrics.maxSidebarWidth)
        XCTAssertEqual(TodayDeskLayout.sidebarCap(containerWidth: 300), TodayDeskMetrics.minSidebarWidth)
    }

    func testClampSidebarHonorsMinMaxAndFraction() {
        XCTAssertEqual(
            TodayDeskLayout.clampSidebar(100, containerWidth: 888),
            TodayDeskMetrics.minSidebarWidth)
        XCTAssertEqual(
            TodayDeskLayout.clampSidebar(400, containerWidth: 2000),
            TodayDeskMetrics.maxSidebarWidth)
        XCTAssertEqual(TodayDeskLayout.clampSidebar(280, containerWidth: 500), 200, accuracy: 0.001)
    }

    func testResolvedDoesNotMutatePreferredWhenWindowClamps() {
        let layout = TodayDeskLayout(
            leftWidth: 320,
            rightWidth: 320,
            leftCollapsed: false,
            rightCollapsed: false)
        let resolved = layout.resolved(containerWidth: 500)
        XCTAssertEqual(layout.leftWidth, 320)
        XCTAssertEqual(layout.rightWidth, 320)
        XCTAssertGreaterThanOrEqual(resolved.centerWidth, TodayDeskMetrics.minCenterWidth - 0.5)
        XCTAssertLessThan(resolved.leftWidth, 320)
        XCTAssertLessThan(resolved.rightWidth, 320)
        XCTAssertEqual(
            resolved.leftWidth + resolved.rightWidth + resolved.centerWidth + TodayDeskMetrics.splitterWidth * 2,
            500,
            accuracy: 0.5)
    }

    func testCenterMinShrinksOnlyTheExpandedSidebar() {
        let layout = TodayDeskLayout(
            leftWidth: 320,
            rightWidth: 320,
            leftCollapsed: true,
            rightCollapsed: false)
        let resolved = layout.resolved(containerWidth: 500)
        XCTAssertEqual(resolved.leftWidth, 0)
        XCTAssertGreaterThanOrEqual(resolved.centerWidth, TodayDeskMetrics.minCenterWidth - 0.5)
        XCTAssertLessThan(resolved.rightWidth, 320)
        XCTAssertGreaterThan(resolved.rightWidth, 0)
    }

    func testDragLeftStopsBeforeEatingTheClock() {
        let layout = TodayDeskLayout.default
        let container: CGFloat = 888
        let other = TodayDeskMetrics.rightSidebarWidth
        let maxLeft = container - TodayDeskMetrics.splitterWidth * 2 - other - TodayDeskMetrics.minCenterWidth
        let dragged = layout.settingLeftWidth(900, containerWidth: container)
        XCTAssertEqual(dragged.leftWidth, min(TodayDeskMetrics.maxSidebarWidth, maxLeft), accuracy: 0.001)
        let resolved = dragged.resolved(containerWidth: container)
        XCTAssertGreaterThanOrEqual(resolved.centerWidth, TodayDeskMetrics.minCenterWidth - 0.5)
    }

    func testDragRightStopsAtMinAndIgnoresWhenCollapsed() {
        let layout = TodayDeskLayout.default
        let shrunk = layout.settingRightWidth(10, containerWidth: 888)
        XCTAssertEqual(shrunk.rightWidth, TodayDeskMetrics.minSidebarWidth)
        let collapsed = layout.togglingRight().settingRightWidth(280, containerWidth: 888)
        XCTAssertTrue(collapsed.rightCollapsed)
        XCTAssertEqual(collapsed.rightWidth, TodayDeskMetrics.rightSidebarWidth)
    }

    func testPersistRoundTripAndSanitizesOutOfRangeWidths() {
        let suite = "today-desk-layout-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(TodayDeskLayout.load(from: defaults), .default)

        let saved = TodayDeskLayout(
            leftWidth: 280,
            rightWidth: 176,
            leftCollapsed: true,
            rightCollapsed: false)
        saved.save(to: defaults)
        XCTAssertEqual(TodayDeskLayout.load(from: defaults), saved)

        defaults.set(9_999.0, forKey: TodayDeskLayout.leftWidthKey)
        defaults.set(-40.0, forKey: TodayDeskLayout.rightWidthKey)
        let sanitized = TodayDeskLayout.load(from: defaults)
        XCTAssertEqual(sanitized.leftWidth, TodayDeskMetrics.maxSidebarWidth)
        XCTAssertEqual(sanitized.rightWidth, TodayDeskMetrics.minSidebarWidth)
        XCTAssertTrue(sanitized.leftCollapsed)
        XCTAssertFalse(sanitized.rightCollapsed)
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
