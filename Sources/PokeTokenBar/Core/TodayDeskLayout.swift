import Foundation

/// Today window chrome. Splitter hit strips replace the old 12pt column gaps.
///
/// NSWindow frame autosave (`PokeTokenBarTodayDesk`) stores the window rect only.
/// Sidebar widths and collapse flags are separate UserDefaults keys on `TodayDeskLayout`
/// / `UsageStore` — layout clamps to the current frame at display time and does not
/// rewrite those keys, so autosave cannot fight persisted sidebar prefs.
enum TodayDeskMetrics {
    static let defaultWidth: CGFloat = 920
    static let defaultHeight: CGFloat = 680
    static let minHeight: CGFloat = 560
    static let leftSidebarWidth: CGFloat = 212
    static let rightSidebarWidth: CGFloat = 232
    static let minSidebarWidth: CGFloat = 160
    static let maxSidebarWidth: CGFloat = 320
    static let maxSidebarFraction: CGFloat = 0.40
    static let minCenterWidth: CGFloat = 360
    static let splitterWidth: CGFloat = 12
    static let chevronHitSize: CGFloat = 32
    static let contentPadding: CGFloat = 16

    static var columnsWidth: CGFloat {
        leftSidebarWidth + rightSidebarWidth + minCenterWidth + splitterWidth * 2
    }

    static var minWidth: CGFloat { columnsWidth + contentPadding * 2 }

    static func fitsThreeColumns(_ width: CGFloat) -> Bool {
        width >= minWidth
    }
}

/// Preferred Today sidebar widths + collapse. Displayed widths come from `resolved(containerWidth:)`.
struct TodayDeskLayout: Equatable, Sendable {
    var leftWidth: CGFloat
    var rightWidth: CGFloat
    var leftCollapsed: Bool
    var rightCollapsed: Bool

    static let leftWidthKey = "todayDeskLeftWidth"
    static let rightWidthKey = "todayDeskRightWidth"
    static let leftCollapsedKey = "todayDeskLeftCollapsed"
    static let rightCollapsedKey = "todayDeskRightCollapsed"

    static let `default` = TodayDeskLayout(
        leftWidth: TodayDeskMetrics.leftSidebarWidth,
        rightWidth: TodayDeskMetrics.rightSidebarWidth,
        leftCollapsed: false,
        rightCollapsed: false)

    struct Resolved: Equatable, Sendable {
        var leftWidth: CGFloat
        var rightWidth: CGFloat
        var centerWidth: CGFloat
        var leftCollapsed: Bool
        var rightCollapsed: Bool
    }

    static func load(from defaults: UserDefaults) -> TodayDeskLayout {
        TodayDeskLayout(
            leftWidth: sanitizedWidth(
                defaults.object(forKey: leftWidthKey) as? Double,
                fallback: TodayDeskMetrics.leftSidebarWidth),
            rightWidth: sanitizedWidth(
                defaults.object(forKey: rightWidthKey) as? Double,
                fallback: TodayDeskMetrics.rightSidebarWidth),
            leftCollapsed: defaults.object(forKey: leftCollapsedKey) as? Bool ?? false,
            rightCollapsed: defaults.object(forKey: rightCollapsedKey) as? Bool ?? false)
    }

    func save(to defaults: UserDefaults) {
        defaults.set(Double(leftWidth), forKey: Self.leftWidthKey)
        defaults.set(Double(rightWidth), forKey: Self.rightWidthKey)
        defaults.set(leftCollapsed, forKey: Self.leftCollapsedKey)
        defaults.set(rightCollapsed, forKey: Self.rightCollapsedKey)
    }

    static func sanitizedWidth(_ raw: Double?, fallback: CGFloat) -> CGFloat {
        guard let raw, raw.isFinite else { return fallback }
        return min(max(CGFloat(raw), TodayDeskMetrics.minSidebarWidth), TodayDeskMetrics.maxSidebarWidth)
    }

    /// Upper bound for one sidebar: `min(320, 40% of container)`, never below the 160pt floor.
    static func sidebarCap(containerWidth: CGFloat) -> CGFloat {
        let fractionCap = containerWidth * TodayDeskMetrics.maxSidebarFraction
        return max(
            TodayDeskMetrics.minSidebarWidth,
            min(TodayDeskMetrics.maxSidebarWidth, fractionCap))
    }

    static func clampSidebar(_ width: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let cap = sidebarCap(containerWidth: containerWidth)
        return min(max(width, TodayDeskMetrics.minSidebarWidth), cap)
    }

    /// Displayed column widths. Preferred widths are not mutated — shrinking the window
    /// clamps on screen only, so restoring a wider frame restores the persisted prefs.
    func resolved(containerWidth: CGFloat) -> Resolved {
        let splitters = TodayDeskMetrics.splitterWidth * 2
        let available = max(0, containerWidth - splitters)
        var left: CGFloat = leftCollapsed ? 0 : Self.clampSidebar(leftWidth, containerWidth: containerWidth)
        var right: CGFloat = rightCollapsed ? 0 : Self.clampSidebar(rightWidth, containerWidth: containerWidth)
        let overflow = left + right + TodayDeskMetrics.minCenterWidth - available
        if overflow > 0 {
            let shrunk = Self.shrinkForCenter(left: left, right: right, overflow: overflow)
            left = shrunk.left
            right = shrunk.right
        }
        let center = max(0, available - left - right)
        return Resolved(
            leftWidth: left,
            rightWidth: right,
            centerWidth: center,
            leftCollapsed: leftCollapsed,
            rightCollapsed: rightCollapsed)
    }

    func togglingLeft() -> TodayDeskLayout {
        var next = self
        next.leftCollapsed.toggle()
        return next
    }

    func togglingRight() -> TodayDeskLayout {
        var next = self
        next.rightCollapsed.toggle()
        return next
    }

    func settingLeftWidth(_ width: CGFloat, containerWidth: CGFloat) -> TodayDeskLayout {
        guard !leftCollapsed else { return self }
        var next = self
        next.leftWidth = Self.clampDragWidth(
            width,
            otherDisplayed: rightCollapsed ? 0 : Self.clampSidebar(rightWidth, containerWidth: containerWidth),
            containerWidth: containerWidth)
        return next
    }

    func settingRightWidth(_ width: CGFloat, containerWidth: CGFloat) -> TodayDeskLayout {
        guard !rightCollapsed else { return self }
        var next = self
        next.rightWidth = Self.clampDragWidth(
            width,
            otherDisplayed: leftCollapsed ? 0 : Self.clampSidebar(leftWidth, containerWidth: containerWidth),
            containerWidth: containerWidth)
        return next
    }

    static func clampDragWidth(
        _ proposed: CGFloat,
        otherDisplayed: CGFloat,
        containerWidth: CGFloat
    ) -> CGFloat {
        let cap = sidebarCap(containerWidth: containerWidth)
        let maxForCenter = containerWidth
            - TodayDeskMetrics.splitterWidth * 2
            - otherDisplayed
            - TodayDeskMetrics.minCenterWidth
        let upper = min(cap, max(0, maxForCenter))
        let lower = min(TodayDeskMetrics.minSidebarWidth, upper)
        return min(max(proposed, lower), upper)
    }

    static func shrinkForCenter(left: CGFloat, right: CGFloat, overflow: CGFloat) -> (left: CGFloat, right: CGFloat) {
        var left = left
        var right = right
        let remaining = overflow
        let total = left + right
        if total <= 0 || remaining <= 0 { return (max(0, left), max(0, right)) }
        if remaining >= total { return (0, 0) }
        let takeLeft = remaining * (left / total)
        left -= takeLeft
        right -= remaining - takeLeft
        return (max(0, left), max(0, right))
    }
}
