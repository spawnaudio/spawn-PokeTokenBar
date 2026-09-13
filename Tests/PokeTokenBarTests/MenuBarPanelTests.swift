import AppKit
import XCTest
@testable import PokeTokenBar

final class MenuBarPanelTests: XCTestCase {
    func testDefaultIsCompactAndMaxStaysBelowToday() {
        XCTAssertEqual(MenuBarPanelMetrics.minWidth, 360)
        XCTAssertEqual(MenuBarPanelMetrics.defaultWidth, 360)
        XCTAssertEqual(MenuBarPanelMetrics.attachedMaxWidth, 500)
        XCTAssertLessThan(MenuBarPanelMetrics.attachedMaxWidth, TodayDeskMetrics.defaultWidth)
        XCTAssertLessThan(MenuBarPanelMetrics.attachedMaxHeight, TodayDeskMetrics.defaultHeight)
        XCTAssertGreaterThanOrEqual(MenuBarPanelMetrics.minHeight, 520)
        XCTAssertGreaterThan(MenuBarPanelMetrics.detachedMaxWidth, MenuBarPanelMetrics.attachedMaxWidth)
    }

    func testIdentifiersAreNotSettingsPlaceholders() {
        XCTAssertEqual(LaunchWindowPolicy.menuBarPanelIdentifier, "PokeTokenBar.MenuBarPanel")
        XCTAssertEqual(LaunchWindowPolicy.menuBarPanelAutosaveName, "PokeTokenBarMenuBarPanel")
        XCTAssertFalse(LaunchWindowPolicy.isSwiftUISettingsPlaceholder(
            identifier: LaunchWindowPolicy.menuBarPanelIdentifier,
            autosaveName: LaunchWindowPolicy.menuBarPanelAutosaveName))
    }

    @MainActor
    func testConfigureAttachedLocksUnderMenuBar() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true)
        MenuBarPanelMetrics.configure(window, detached: false)
        XCTAssertFalse(window.isMovable)
        XCTAssertFalse(window.isMovableByWindowBackground)
        XCTAssertFalse(window.hidesOnDeactivate)
        XCTAssertTrue(window.styleMask.contains(.borderless))
        XCTAssertFalse(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertEqual(window.contentMinSize.width, 360)
        XCTAssertEqual(window.contentMaxSize.width, 500)
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, NSColor.clear)
        XCTAssertEqual(window.contentView?.layer?.cornerRadius, 12)
    }

    @MainActor
    func testConfigureDetachedIsMovableTitledWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 640),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true)
        MenuBarPanelMetrics.configure(window, detached: true)
        XCTAssertTrue(window.isMovable)
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertGreaterThan(window.contentMaxSize.width, MenuBarPanelMetrics.attachedMaxWidth)
    }

    func testOnlyTheButtonDetachesFromTheMenuBar() {
        XCTAssertTrue(MenuBarPanelMetrics.shouldPlaceBelowStatusItem(detached: false))
        XCTAssertFalse(MenuBarPanelMetrics.shouldPlaceBelowStatusItem(detached: true))
    }

    func testClampedContentSizePinsToMinAndMax() {
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(NSSize(width: 200, height: 100), detached: false),
            NSSize(width: 360, height: 520))
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(NSSize(width: 200, height: 100), detached: true),
            NSSize(width: MenuBarPanelMetrics.minContentWidth(detached: true), height: 400))
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(
                NSSize(width: 200, height: 100),
                detached: true,
                sidebarCollapsed: true),
            NSSize(width: MenuBarPanelMetrics.minContentWidth(detached: true, sidebarCollapsed: true), height: 400))
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(NSSize(width: 900, height: 900), detached: false),
            NSSize(width: 500, height: 660))
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(NSSize(width: 900, height: 900), detached: true),
            NSSize(width: 900, height: 900))
        XCTAssertEqual(
            MenuBarPanelMetrics.clampedContentSize(NSSize(width: 500, height: 600), detached: false),
            NSSize(width: 500, height: 600))
        XCTAssertEqual(MenuBarPanelMetrics.maxWidth(detached: false), 500)
        XCTAssertEqual(MenuBarPanelMetrics.maxWidth(detached: true), 2400)
    }

    func testFrameBelowStatusItemCentersAndClampsToScreen() {
        let button = NSRect(x: 620, y: 800, width: 40, height: 22)
        let screen = NSRect(x: 0, y: 0, width: 1280, height: 800)
        let size = NSSize(width: 360, height: 640)
        let frame = MenuBarPanelMetrics.frame(below: button, size: size, visibleScreen: screen)
        XCTAssertEqual(frame.width, 360)
        XCTAssertEqual(frame.height, 640)
        XCTAssertEqual(frame.midX, button.midX, accuracy: 0.5)
        XCTAssertEqual(frame.maxY, button.minY - MenuBarPanelMetrics.statusItemGap, accuracy: 0.5)

        let tight = NSRect(x: 0, y: 0, width: 300, height: 400)
        let clamped = MenuBarPanelMetrics.frame(
            below: NSRect(x: 0, y: 400, width: 20, height: 22),
            size: NSSize(width: 360, height: 640),
            visibleScreen: tight)
        XCTAssertEqual(clamped.width, 300)
        XCTAssertEqual(clamped.height, 400)
        XCTAssertGreaterThanOrEqual(clamped.minX, tight.minX)
        XCTAssertLessThanOrEqual(clamped.maxX, tight.maxX)
        XCTAssertGreaterThanOrEqual(clamped.minY, tight.minY)
        XCTAssertLessThanOrEqual(clamped.maxY, tight.maxY)
    }

    @MainActor
    func testBackLeavesNonFocusTabsAndSettings() {
        let nav = PopoverNavigation()
        XCTAssertFalse(nav.canGoBack)
        nav.tab = .linear
        XCTAssertTrue(nav.canGoBack)
        nav.goBack()
        XCTAssertEqual(nav.tab, .focus)
        XCTAssertFalse(nav.canGoBack)

        nav.tab = .collection
        nav.showSettings = true
        XCTAssertTrue(nav.canGoBack)
        nav.goBack()
        XCTAssertFalse(nav.showSettings)
        XCTAssertEqual(nav.tab, .collection)
        nav.goBack()
        XCTAssertEqual(nav.tab, .focus)
    }

    func testPopoverShellUsesInsetContentPanel() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTokenBar/UI")
        let popover = try String(
            contentsOf: root.appendingPathComponent("PopoverView.swift"), encoding: .utf8)
        let chrome = try String(
            contentsOf: root.appendingPathComponent("PopoverChrome.swift"), encoding: .utf8)
        XCTAssertTrue(popover.contains("PopoverShellToolbar"))
        XCTAssertTrue(popover.contains("popoverInsetCanvas"))
        XCTAssertTrue(popover.contains("shellFill"))
        XCTAssertTrue(popover.contains("attachedCornerRadius"))
        XCTAssertTrue(popover.contains("shellGap"))
        XCTAssertTrue(chrome.contains("func popoverInsetCanvas"))
        XCTAssertTrue(chrome.contains("canvasFill"))
        XCTAssertTrue(chrome.contains("struct PopoverChromeActionButtons"))
        XCTAssertTrue(chrome.contains("struct MenuBarSidebarNav"))
        XCTAssertTrue(chrome.contains("struct ChromeColumnSplitter"))
        XCTAssertTrue(popover.contains("menuBarSidebarLayout"))
        XCTAssertTrue(popover.contains("PopoverChromeActionButtons(vertical: collapsed)"))
        XCTAssertTrue(popover.contains("MenuBarSidebarNav"))
        XCTAssertTrue(chrome.contains("var vertical: Bool"))
    }

    func testFocusTabKeepsUsageAndTimeXPSeparate() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PokeTokenBar/UI")
        let focus = try String(contentsOf: root.appendingPathComponent("FocusTabView.swift"), encoding: .utf8)
        XCTAssertFalse(focus.contains("pomodoroSection"))
        XCTAssertFalse(focus.contains("session.openPomodoroSetup()"))
        XCTAssertFalse(focus.contains("l.pomoTimer"))
        XCTAssertTrue(focus.contains("linearSection"))
        XCTAssertTrue(focus.contains("showsRefresh: true"))
        XCTAssertTrue(focus.contains("TimeXPView"))
        XCTAssertTrue(focus.contains("CompanionHeader(store: companion)"))
        XCTAssertTrue(focus.contains(".popoverCard()"))
        let companionRange = try XCTUnwrap(focus.range(of: "CompanionHeader(store: companion)"))
        let nextToken = focus[companionRange.upperBound...]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        XCTAssertFalse(
            nextToken.hasPrefix(".popoverCard("),
            "CompanionHeader is a canvas hero, not a hairline content card")
    }
}
