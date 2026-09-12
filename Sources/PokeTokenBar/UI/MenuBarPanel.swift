import AppKit
import SwiftUI

extension LaunchWindowPolicy {
    static let menuBarPanelIdentifier = "PokeTokenBar.MenuBarPanel"
    static let menuBarPanelAutosaveName = "PokeTokenBarMenuBarPanel"
}

/// Sticky menu-bar window. Default is the current 360pt compact size; the user
/// can stretch it toward Today, but not past 720pt (Today is 920×680).
enum MenuBarPanelMetrics {
    static let defaultWidth: CGFloat = PopoverMetrics.width
    static let defaultHeight: CGFloat = 640
    static let minWidth: CGFloat = PopoverMetrics.width
    static let minHeight: CGFloat = 520
    static let maxWidth: CGFloat = 720
    static let maxHeight: CGFloat = 660
    static let statusItemGap: CGFloat = 6

    static var defaultContentSize: NSSize {
        NSSize(width: defaultWidth, height: defaultHeight)
    }

    @MainActor
    static func configure(_ window: NSWindow) {
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentMinSize = NSSize(width: minWidth, height: minHeight)
        window.contentMaxSize = NSSize(width: maxWidth, height: maxHeight)
    }

    static func clampedContentSize(_ size: NSSize) -> NSSize {
        NSSize(
            width: min(max(size.width, minWidth), maxWidth),
            height: min(max(size.height, minHeight), maxHeight))
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
        if window?.isMiniaturized == true || isShown {
            presentExisting()
            return
        }
        if resetNavigation { navigation.reset() }
        NSApp.activate(ignoringOtherApps: true)
        if window == nil { window = makeWindow() }
        if window?.contentView == nil { window?.contentView = hostedView() }
        applyTitle()
        clampContentSize()
        if let button, shouldPlaceBelowStatusItem {
            place(below: button)
        }
        window?.makeKeyAndOrderFront(nil)
        onVisibilityChange?()
    }

    func close() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        onVisibilityChange?()
    }

    private var shouldPlaceBelowStatusItem: Bool {
        window?.frame.origin == .zero
    }

    private func presentExisting() {
        NSApp.activate(ignoringOtherApps: true)
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        onVisibilityChange?()
    }

    private func hostedView() -> NSView {
        NSHostingView(rootView:
            PopoverView()
                .environment(usage)
                .environment(companion)
                .environment(updater)
                .environment(navigation)
                .environment(session)
                .environment(\.locale, companion.language.displayLocale)
        )
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: MenuBarPanelMetrics.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        MenuBarPanelMetrics.configure(window)
        window.identifier = NSUserInterfaceItemIdentifier(LaunchWindowPolicy.menuBarPanelIdentifier)
        window.setFrameAutosaveName(LaunchWindowPolicy.menuBarPanelAutosaveName)
        window.delegate = self
        window.contentView = hostedView()
        return window
    }

    private func applyTitle() {
        window?.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "PokeTokenBar"
    }

    private func clampContentSize() {
        guard let window else { return }
        let current = window.contentRect(forFrameRect: window.frame).size
        let clamped = MenuBarPanelMetrics.clampedContentSize(current)
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
