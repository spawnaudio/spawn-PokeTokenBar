import AppKit
import SwiftUI

extension LaunchWindowPolicy {
    static let menuBarPanelIdentifier = "PokeTokenBar.MenuBarPanel"
    static let menuBarPanelAutosaveName = "PokeTokenBarMenuBarPanel"
}

/// Sticky menu-bar window. Default is the current 360pt compact size; attached
/// stretch stops at 500pt. Detached uses normal window min/max (no 500pt cap).
enum MenuBarPanelMetrics {
    static let defaultWidth: CGFloat = PopoverMetrics.width
    static let defaultHeight: CGFloat = 640
    static let minWidth: CGFloat = PopoverMetrics.width
    static let minHeight: CGFloat = 520
    static let attachedMaxWidth: CGFloat = 500
    static let attachedMaxHeight: CGFloat = 660
    static let detachedMinHeight: CGFloat = 400
    static let detachedMaxWidth: CGFloat = 2400
    static let detachedMaxHeight: CGFloat = 2400
    static let maxWidth: CGFloat = detachedMaxWidth
    static let maxHeight: CGFloat = attachedMaxHeight
    static let statusItemGap: CGFloat = 6
    static let shellGap: CGFloat = 8
    static let attachedCornerRadius: CGFloat = 12
    /// Room for traffic lights on a unified hidden titlebar.
    static let detachedTrafficLightInset: CGFloat = 76
    static let detachedKey = "menuBarPanelDetached"
    static let sidebarWidthKey = "menuBarSidebarWidth"
    static let sidebarCollapsedKey = "menuBarSidebarCollapsed"
    static let sidebarDefaultWidth: CGFloat = 176
    static let sidebarMinWidth: CGFloat = 148
    static let sidebarMaxWidth: CGFloat = 260
    static let splitterWidth: CGFloat = TodayDeskMetrics.splitterWidth
    static let collapsedStripWidth: CGFloat = detachedTrafficLightInset
    static let sidebarTrafficLightClearance: CGFloat = 36

    static var defaultContentSize: NSSize {
        NSSize(width: defaultWidth, height: defaultHeight)
    }

    static var attachedStyleMask: NSWindow.StyleMask { [.borderless, .resizable] }
    static var detachedStyleMask: NSWindow.StyleMask {
        [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
    }

    static func maxWidth(detached: Bool) -> CGFloat {
        detached ? detachedMaxWidth : attachedMaxWidth
    }

    static func minHeight(detached: Bool) -> CGFloat {
        detached ? detachedMinHeight : minHeight
    }

    static func maxHeight(detached: Bool) -> CGFloat {
        detached ? detachedMaxHeight : attachedMaxHeight
    }

    static func clampedSidebarWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, sidebarMinWidth), sidebarMaxWidth)
    }

    static func minContentWidth(
        detached: Bool,
        sidebarCollapsed: Bool = false,
        sidebarWidth: CGFloat = sidebarDefaultWidth
    ) -> CGFloat {
        guard detached else { return minWidth }
        if sidebarCollapsed { return minWidth + collapsedStripWidth }
        return minWidth + clampedSidebarWidth(sidebarWidth) + splitterWidth
    }

    /// Linear light: sidebar `#F3F4F6`, page white. Dark keeps a matching split.
    static var shellFill: NSColor {
        dynamicColor(
            name: "PTBShellFill",
            light: NSColor(srgbRed: 0.953, green: 0.957, blue: 0.965, alpha: 1),
            dark: NSColor(srgbRed: 0.141, green: 0.145, blue: 0.161, alpha: 1))
    }

    static var canvasFill: NSColor {
        dynamicColor(
            name: "PTBCanvasFill",
            light: .white,
            dark: NSColor(srgbRed: 0.090, green: 0.094, blue: 0.106, alpha: 1))
    }

    static var cardFill: NSColor {
        dynamicColor(
            name: "PTBCardFill",
            light: .white,
            dark: NSColor.white.withAlphaComponent(0.06))
    }

    static var chipFill: NSColor {
        dynamicColor(
            name: "PTBChipFill",
            light: NSColor.black.withAlphaComponent(0.04),
            dark: NSColor.white.withAlphaComponent(0.06))
    }

    static var selectedFill: NSColor {
        dynamicColor(
            name: "PTBSelectedFill",
            light: NSColor.black.withAlphaComponent(0.08),
            dark: NSColor.white.withAlphaComponent(0.12))
    }

    static var hairline: NSColor {
        dynamicColor(
            name: "PTBHairline",
            light: NSColor.black.withAlphaComponent(0.10),
            dark: NSColor.white.withAlphaComponent(0.16))
    }

    static var hairlineSelected: NSColor {
        dynamicColor(
            name: "PTBHairlineSelected",
            light: NSColor.black.withAlphaComponent(0.14),
            dark: NSColor.white.withAlphaComponent(0.22))
    }

    private static func dynamicColor(name: String, light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: name) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    /// Dragging does not detach. Only the in-panel button does.
    static func shouldPlaceBelowStatusItem(detached: Bool) -> Bool { !detached }

    @MainActor
    static func configure(
        _ window: NSWindow,
        detached: Bool,
        sidebarCollapsed: Bool = false,
        sidebarWidth: CGFloat = sidebarDefaultWidth
    ) {
        window.styleMask = detached ? detachedStyleMask : attachedStyleMask
        window.isMovable = detached
        window.isMovableByWindowBackground = detached
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentMinSize = NSSize(
            width: minContentWidth(
                detached: detached,
                sidebarCollapsed: sidebarCollapsed,
                sidebarWidth: sidebarWidth),
            height: minHeight(detached: detached))
        window.contentMaxSize = NSSize(
            width: maxWidth(detached: detached),
            height: maxHeight(detached: detached))
        window.setFrameAutosaveName(detached ? LaunchWindowPolicy.menuBarPanelAutosaveName : "")
        window.titleVisibility = detached ? .hidden : .visible
        window.titlebarAppearsTransparent = detached
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unifiedCompact
        window.toolbar = nil
        if detached {
            window.isOpaque = true
            window.backgroundColor = shellFill
        } else {
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        applyAttachedClip(window.contentView, detached: detached)
        window.invalidateShadow()
    }

    @MainActor
    static func applyAttachedClip(_ view: NSView?, detached: Bool) {
        guard let view else { return }
        view.wantsLayer = true
        view.layer?.cornerRadius = detached ? 0 : attachedCornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = !detached
        view.layer?.backgroundColor = detached ? nil : NSColor.clear.cgColor
    }

    static func clampedContentSize(
        _ size: NSSize,
        detached: Bool = true,
        sidebarCollapsed: Bool = false,
        sidebarWidth: CGFloat = sidebarDefaultWidth
    ) -> NSSize {
        NSSize(
            width: min(
                max(
                    size.width,
                    minContentWidth(
                        detached: detached,
                        sidebarCollapsed: sidebarCollapsed,
                        sidebarWidth: sidebarWidth)),
                maxWidth(detached: detached)),
            height: min(max(size.height, minHeight(detached: detached)), maxHeight(detached: detached)))
    }

    /// Place `size` under the status item, clamped to `visibleScreen`.
    static func frame(below buttonScreenRect: NSRect, size: NSSize, visibleScreen: NSRect) -> NSRect {
        let width = min(max(size.width, 1), max(visibleScreen.width, 1))
        let height = min(max(size.height, 1), max(visibleScreen.height, 1))
        var frame = NSRect(
            x: buttonScreenRect.midX - width / 2,
            y: buttonScreenRect.minY - height - statusItemGap,
            width: width,
            height: height)
        frame.origin.x = min(
            max(frame.origin.x, visibleScreen.minX),
            visibleScreen.maxX - frame.width)
        frame.origin.y = min(
            max(frame.origin.y, visibleScreen.minY),
            visibleScreen.maxY - frame.height)
        return frame
    }
}

/// Menu-bar panel. Stays open on click-outside and focus loss; hosting is
/// still torn down on close so a hidden tree cannot idle-relayout (energy).
@MainActor
final class MenuBarPanelController: NSObject, NSWindowDelegate {
    private let usage: UsageStore
    private let companion: CompanionStore
    private let session: FocusSessionStore
    private let updater: UpdateChecker
    private let navigation: PopoverNavigation
    private var window: NSWindow?
    private weak var statusButton: NSStatusBarButton?
    var onVisibilityChange: (() -> Void)?

    init(
        usage: UsageStore,
        companion: CompanionStore,
        session: FocusSessionStore,
        updater: UpdateChecker,
        navigation: PopoverNavigation
    ) {
        self.usage = usage
        self.companion = companion
        self.session = session
        self.updater = updater
        self.navigation = navigation
        super.init()
        observeDetach()
    }

    var isShown: Bool { window?.isVisible == true }

    func toggle(from button: NSStatusBarButton) {
        if window?.isMiniaturized == true {
            presentExisting()
            return
        }
        if isShown {
            close()
        } else {
            present(from: button, resetNavigation: true)
        }
    }

    /// Pet / deep-link: show or bring forward. Does not close an already-open panel.
    func present(from button: NSStatusBarButton?, resetNavigation: Bool) {
        if let button { statusButton = button }
        if window?.isMiniaturized == true || isShown {
            presentExisting()
            return
        }
        if resetNavigation { navigation.reset() }
        NSApp.activate(ignoringOtherApps: true)
        if window == nil { window = makeWindow() }
        if window?.contentView == nil { window?.contentView = hostedView() }
        applyTitle()
        applyChrome()
        clampContentSize()
        if let button, MenuBarPanelMetrics.shouldPlaceBelowStatusItem(detached: usage.menuBarPanelDetached) {
            place(below: button)
        }
        window?.makeKeyAndOrderFront(nil)
        onVisibilityChange?()
    }

    func close() {
        window?.orderOut(nil)
        window?.contentView = nil
        onVisibilityChange?()
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        onVisibilityChange?()
    }

    func windowDidResize(_ notification: Notification) {
        MenuBarPanelMetrics.applyAttachedClip(window?.contentView, detached: usage.menuBarPanelDetached)
        window?.invalidateShadow()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        clampContentSize()
        window?.invalidateShadow()
    }

    private func presentExisting() {
        NSApp.activate(ignoringOtherApps: true)
        window?.deminiaturize(nil)
        applyChrome()
        if let statusButton, MenuBarPanelMetrics.shouldPlaceBelowStatusItem(detached: usage.menuBarPanelDetached) {
            place(below: statusButton)
        }
        window?.makeKeyAndOrderFront(nil)
        onVisibilityChange?()
    }

    private func hostedView() -> NSView {
        let view = NSHostingView(rootView:
            PopoverView()
                .environment(usage)
                .environment(companion)
                .environment(updater)
                .environment(navigation)
                .environment(session)
                .environment(\.locale, companion.language.displayLocale)
        )
        MenuBarPanelMetrics.applyAttachedClip(view, detached: usage.menuBarPanelDetached)
        return view
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: MenuBarPanelMetrics.defaultContentSize),
            styleMask: MenuBarPanelMetrics.attachedStyleMask,
            backing: .buffered,
            defer: false)
        window.identifier = NSUserInterfaceItemIdentifier(LaunchWindowPolicy.menuBarPanelIdentifier)
        window.delegate = self
        window.contentView = hostedView()
        configureWindow(window)
        return window
    }

    private func applyTitle() {
        window?.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "PokeTokenBar"
    }

    private func applyChrome() {
        guard let window else { return }
        configureWindow(window)
        applyTitle()
    }

    private func configureWindow(_ window: NSWindow) {
        MenuBarPanelMetrics.configure(
            window,
            detached: usage.menuBarPanelDetached,
            sidebarCollapsed: usage.menuBarSidebarCollapsed,
            sidebarWidth: CGFloat(usage.menuBarSidebarWidth))
    }

    private func observeDetach() {
        withObservationTracking {
            _ = usage.menuBarPanelDetached
            _ = usage.menuBarSidebarCollapsed
            _ = usage.menuBarSidebarWidth
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyChrome()
                self.clampContentSize()
                if let statusButton = self.statusButton,
                   MenuBarPanelMetrics.shouldPlaceBelowStatusItem(detached: self.usage.menuBarPanelDetached)
                {
                    self.place(below: statusButton)
                }
                self.observeDetach()
            }
        }
    }

    private func clampContentSize() {
        guard let window else { return }
        let current = window.contentRect(forFrameRect: window.frame).size
        let clamped = MenuBarPanelMetrics.clampedContentSize(
            current,
            detached: usage.menuBarPanelDetached,
            sidebarCollapsed: usage.menuBarSidebarCollapsed,
            sidebarWidth: CGFloat(usage.menuBarSidebarWidth))
        if clamped != current {
            window.setContentSize(clamped)
        }
    }

    private func place(below button: NSStatusBarButton) {
        guard let window, let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let size = window.frame.size
        window.setFrame(
            MenuBarPanelMetrics.frame(below: buttonRect, size: size, visibleScreen: screen),
            display: false)
    }
}
