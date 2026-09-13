import AppKit
import SwiftUI

/// Popover material (`NSVisualEffectView.Material.popover`) so the menu-bar panel
/// follows system light/dark instead of an opaque window fill.
@MainActor
struct PopoverMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Shared 0.5pt hairline so buttons, chips, tabs, and cards all read as bordered.
enum TahoeHairline {
    static let width: CGFloat = 0.5
    static let idle = Color(nsColor: MenuBarPanelMetrics.hairline)
    static let selected = Color(nsColor: MenuBarPanelMetrics.hairlineSelected)

    static func tinted(_ color: Color) -> Color { color.opacity(0.45) }
}

/// Opaque card: 12pt continuous corners + hairline.
@MainActor
struct PopoverCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: MenuBarPanelMetrics.cardFill))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(TahoeHairline.idle, lineWidth: TahoeHairline.width)
            }
    }
}

/// Primary / secondary / toolbar buttons. Linear filled / chip / plain.
enum TahoeButtonKind {
    case prominent
    case regular
    case accessory
}

/// Layout-only cluster.
@MainActor
struct TahoeGlassCluster<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View { content }
}

extension View {
    func popoverCard() -> some View {
        modifier(PopoverCardModifier())
    }

    /// Quiet bordered pill for menus/dropdowns.
    func linearChipChrome(expands: Bool = false, tint: Color? = nil) -> some View {
        self
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: expands ? .infinity : nil, alignment: .leading)
            .background((tint?.opacity(0.16) ?? Color(nsColor: MenuBarPanelMetrics.chipFill)), in: Capsule())
            .overlay {
                Capsule().strokeBorder(
                    tint.map(TahoeHairline.tinted) ?? TahoeHairline.idle,
                    lineWidth: TahoeHairline.width)
            }
    }

    /// Quiet segmented item: selected is a filled pill (`--bg-control`) plus a hairline.
    func linearSegmentChrome(selected: Bool) -> some View {
        self
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? Color(nsColor: MenuBarPanelMetrics.selectedFill) : Color.clear, in: Capsule())
            .overlay {
                Capsule().strokeBorder(
                    selected ? TahoeHairline.selected : TahoeHairline.idle,
                    lineWidth: TahoeHairline.width)
            }
    }

    /// Toolbar strip: filled control surface + hairline.
    func popoverBottomBarChrome() -> some View {
        self
            .background(Color(nsColor: MenuBarPanelMetrics.chipFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(TahoeHairline.idle, lineWidth: TahoeHairline.width)
            }
    }

    /// Button chrome. Prominent = filled control; regular = chip; accessory = plain.
    @ViewBuilder
    func tahoeButtonStyle(_ kind: TahoeButtonKind) -> some View {
        switch kind {
        case .prominent:
            self
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: MenuBarPanelMetrics.selectedFill), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(TahoeHairline.selected, lineWidth: TahoeHairline.width)
                }
        case .regular:
            self.linearChipChrome()
        case .accessory:
            self
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .overlay {
                    Capsule().strokeBorder(TahoeHairline.idle, lineWidth: TahoeHairline.width)
                }
        }
    }

    /// Overlay island / prompt chrome: filled panel.
    func tahoeFloatingChrome(cornerRadius: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Color(nsColor: MenuBarPanelMetrics.cardFill), in: shape)
            .overlay { shape.strokeBorder(TahoeHairline.idle, lineWidth: TahoeHairline.width) }
    }

    func tahoePromptChrome(cornerRadius: CGFloat = 10) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Color(nsColor: MenuBarPanelMetrics.cardFill), in: shape)
            .overlay { shape.strokeBorder(TahoeHairline.idle, lineWidth: TahoeHairline.width) }
    }

    func tahoeIconChrome(selected: Bool = false) -> some View {
        self
            .background(
                selected ? Color(nsColor: MenuBarPanelMetrics.selectedFill) : Color.clear,
                in: Circle())
            .overlay {
                Circle().strokeBorder(
                    selected ? TahoeHairline.selected : TahoeHairline.idle,
                    lineWidth: TahoeHairline.width)
            }
    }
}

enum TahoeChromeSymbol {
    /// Trailing menu affordance on popup chips.
    static let menuChevron = "chevron.down"
}

/// Closest SF Symbols to Linear’s chrome (issue circle / project hexagon / initiative flag).
enum LinearChromeSymbol {
    static let issue = "circle"
    static let project = "hexagon"
    static let initiative = "flag"
}

/// Quiet popup label: current value plus a trailing chevron.
@MainActor
struct TahoeMenuLabel: View {
    let text: String
    var expands: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .lineLimit(1)
            if expands { Spacer(minLength: 4) }
            Image(systemName: TahoeChromeSymbol.menuChevron)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .accessibilityHidden(true)
        }
    }
}

/// Menu-styled picker as a quiet bordered chip with a chevron.
@MainActor
struct TahoePopupMenu<Selection: Hashable, Content: View>: View {
    let accessibilityLabel: String
    let selectionTitle: String
    @Binding var selection: Selection
    var size: ControlSize = .small
    var expands: Bool = false
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            Picker(accessibilityLabel, selection: $selection) {
                content
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            TahoeMenuLabel(text: selectionTitle, expands: expands)
                .foregroundStyle(tint ?? Color.primary)
        }
        .menuIndicator(.hidden)
        .linearChipChrome(expands: expands, tint: tint)
        .controlSize(size)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(selectionTitle)
    }
}

struct TahoeTabItem<Value: Hashable> {
    let value: Value
    let title: String
    var symbol: String? = nil
    var symbolColor: Color? = nil

    init(_ value: Value, title: String, symbol: String? = nil, symbolColor: Color? = nil) {
        self.value = value
        self.title = title
        self.symbol = symbol
        self.symbolColor = symbolColor
    }
}

/// Selected = filled quiet pill, idle = no fill. Labels collapse to icons
/// when the labeled cluster would wrap.
@MainActor
struct TahoeTabBar<Value: Hashable>: View {
    @Binding var selection: Value
    var size: ControlSize = .small
    let items: [TahoeTabItem<Value>]

    private var canCollapseToIcons: Bool {
        items.allSatisfy { $0.symbol != nil }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            tabRow(showTitle: true)
                .fixedSize(horizontal: true, vertical: false)
            if canCollapseToIcons {
                tabRow(showTitle: false)
            }
        }
    }

    private func tabRow(showTitle: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.value) { item in
                let selected = selection == item.value
                Button {
                    selection = item.value
                } label: {
                    HStack(spacing: 5) {
                        if let symbol = item.symbol {
                            Image(systemName: symbol)
                                .foregroundStyle(
                                    item.symbolColor ?? (selected ? Color.primary : Color.secondary))
                        }
                        if showTitle {
                            Text(item.title)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
                .font(.system(size: 13, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .linearSegmentChrome(selected: selected)
                .controlSize(size)
                .help(item.title)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// 24–28pt metadata pill: quiet border, optional team/status tint.
@MainActor
struct LinearTagChip: View {
    let text: String
    var tint: Color? = nil

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint ?? Color.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((tint?.opacity(0.16) ?? Color(nsColor: MenuBarPanelMetrics.chipFill)), in: Capsule())
            .overlay {
                Capsule().strokeBorder(
                    tint.map(TahoeHairline.tinted) ?? TahoeHairline.idle,
                    lineWidth: TahoeHairline.width)
            }
    }
}

/// Muted label, brighter value — inspector / composer property rows.
@MainActor
struct LinearPropertyRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            value
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}

/// Caption2 tertiary labels for Focus / Usage section headers.
@MainActor
struct PopoverSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}

/// Muted track + accent fill (shadcn-style). Limits keep their own warn/crit tints.
@MainActor
struct MutedProgressBar: View {
    var value: Double
    var total: Double = 1

    var body: some View {
        let fraction = total > 0 ? min(max(value / total, 0), 1) : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(nsColor: MenuBarPanelMetrics.chipFill))
                    .overlay {
                        Capsule().strokeBorder(TahoeHairline.idle, lineWidth: TahoeHairline.width)
                    }
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(4, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
        .accessibilityValue(Text("\(Int((fraction * 100).rounded()))%"))
    }
}

@MainActor
struct FocusPauseButton: View {
    let paused: Bool
    let disabled: Bool
    let pauseTitle: String
    let resumeTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                Label(paused ? resumeTitle : pauseTitle,
                      systemImage: paused ? "play.fill" : "pause.fill")
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: paused ? "play.fill" : "pause.fill")
            }
        }
        .tahoeButtonStyle(.prominent)
        .controlSize(.regular)
        .disabled(disabled)
        .help(paused ? resumeTitle : pauseTitle)
        .accessibilityLabel(paused ? resumeTitle : pauseTitle)
    }
}

/// Linear filled primary for Mark done (Today / Focus). Lists stay unboxed.
@MainActor
struct FocusMarkDoneButton: View {
    let title: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .tahoeButtonStyle(.prominent)
            .controlSize(.regular)
            .disabled(disabled)
    }
}

@MainActor
struct PopoverChromeActionButtons: View {
    @Environment(PopoverNavigation.self) private var nav
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion
    @Environment(UsageStore.self) private var store

    var spreadsAcrossBar: Bool = false

    private var l: L { companion.l }

    var body: some View {
        HStack(spacing: 8) {
            iconButton(
                systemName: store.menuBarPanelDetached ? "menubar.arrow.up.rectangle" : "macwindow.on.rectangle",
                help: store.menuBarPanelDetached ? l.attachMenuBarPanel : l.detachMenuBarPanel,
                label: store.menuBarPanelDetached ? l.attachMenuBarPanel : l.detachMenuBarPanel,
                selected: store.menuBarPanelDetached
            ) {
                store.menuBarPanelDetached.toggle()
            }
            iconButton(systemName: "calendar", help: l.todayDeskMenuOpen, label: l.todayDeskWindowTitle) {
                session.openDesk()
            }
            if spreadsAcrossBar { Spacer(minLength: 8) }
            iconButton(systemName: "gearshape", help: l.settings, label: l.settings, selected: nav.showSettings) {
                nav.showSettings.toggle()
            }
        }
    }

    private func iconButton(
        systemName: String,
        help: String,
        label: String,
        selected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .frame(width: 32, height: 32)
                .tahoeIconChrome(selected: selected)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(label)
    }
}

@MainActor
struct PopoverShellToolbar: View {
    @Environment(PopoverNavigation.self) private var nav
    @Environment(CompanionStore.self) private var companion

    var showsTabs: Bool = true
    var showsActions: Bool = true
    var showsBack: Bool = true

    private var l: L { companion.l }

    var body: some View {
        HStack(spacing: 8) {
            if showsBack, nav.canGoBack {
                Button {
                    nav.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                        .tahoeIconChrome()
                }
                .buttonStyle(.plain)
                .help(l.goBack)
                .accessibilityLabel(l.goBack)
            }

            if showsTabs {
                ViewThatFits(in: .horizontal) {
                    tabRow(showTitle: true)
                        .fixedSize(horizontal: true, vertical: false)
                    tabRow(showTitle: false)
                }
            }
            if showsActions {
                if showsTabs { Spacer(minLength: 8) }
                PopoverChromeActionButtons()
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private func tabRow(showTitle: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(PopoverTab.allCases, id: \.self) { tab in
                let selected = !nav.showSettings && nav.tab == tab
                Button {
                    nav.showSettings = false
                    nav.tab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                        if showTitle {
                            Text(tab.title(l))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .font(.system(size: 13, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .padding(.horizontal, showTitle ? 10 : 8)
                    .padding(.vertical, 6)
                    .background(
                        selected ? Color(nsColor: MenuBarPanelMetrics.selectedFill) : Color.clear,
                        in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(
                            selected ? TahoeHairline.selected : TahoeHairline.idle,
                            lineWidth: TahoeHairline.width)
                    }
                }
                .buttonStyle(.plain)
                .help(tab.title(l))
                .accessibilityLabel(tab.title(l))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// Hairline column splitter + overlay-sized fold chevron. Drag resizes; chevron or
/// double-click collapses. Collapsed sidebars keep this strip so they can expand.
@MainActor
struct ChromeColumnSplitter: View {
    var collapsed: Bool
    var displayedWidth: CGFloat
    var growsWhenDraggedPositive: Bool
    var collapseLabel: String
    var expandLabel: String
    var onToggle: () -> Void
    var onDragTo: (CGFloat) -> Void

    @State private var dragOrigin: CGFloat?
    @State private var cursorPushed = false

    private var chevronName: String {
        if growsWhenDraggedPositive {
            return collapsed ? "chevron.right" : "chevron.left"
        }
        return collapsed ? "chevron.left" : "chevron.right"
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(TahoeHairline.idle)
                .frame(width: TahoeHairline.width)
            Button(action: onToggle) {
                Image(systemName: chevronName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: TodayDeskMetrics.chevronHitSize,
                        height: TodayDeskMetrics.chevronHitSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(collapsed ? expandLabel : collapseLabel)
            .accessibilityLabel(collapsed ? expandLabel : collapseLabel)
        }
        .frame(width: TodayDeskMetrics.splitterWidth)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.resizeLeftRight.push()
                cursorPushed = true
            } else if cursorPushed {
                NSCursor.pop()
                cursorPushed = false
            }
        }
        .onDisappear {
            if cursorPushed {
                NSCursor.pop()
                cursorPushed = false
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    guard !collapsed else { return }
                    if dragOrigin == nil { dragOrigin = displayedWidth }
                    let delta = growsWhenDraggedPositive ? value.translation.width : -value.translation.width
                    onDragTo((dragOrigin ?? displayedWidth) + delta)
                }
                .onEnded { _ in
                    dragOrigin = nil
                }
        )
        .onTapGesture(count: 2, perform: onToggle)
    }
}

@MainActor
struct MenuBarSidebarNav: View {
    @Environment(PopoverNavigation.self) private var nav
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }

    var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                navColumn(showTitle: true)
                    .fixedSize(horizontal: true, vertical: false)
                navColumn(showTitle: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func navColumn(showTitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(PopoverTab.allCases, id: \.self) { tab in
                sidebarRow(
                    title: tab.title(l),
                    symbol: tab.symbol,
                    indent: 0,
                    selected: !nav.showSettings && nav.tab == tab && !hasSelectedChild(tab),
                    showTitle: showTitle
                ) {
                    nav.showSettings = false
                    nav.tab = tab
                }
                if tab == .linear {
                    linearChildren(showTitle: showTitle)
                }
                if tab == .collection {
                    collectionChildren(showTitle: showTitle)
                }
            }
        }
    }

    @ViewBuilder
    private func linearChildren(showTitle: Bool) -> some View {
        sidebarRow(
            title: l.linearIssuesTab,
            symbol: LinearChromeSymbol.issue,
            indent: 1,
            selected: false,
            showTitle: showTitle
        ) {
            nav.showLinear(.issues)
        }
        ForEach(LinearIssuesTab.allCases, id: \.self) { tab in
            sidebarRow(
                title: tab.title(l),
                symbol: tab.symbol,
                indent: 2,
                selected: nav.tab == .linear && nav.linearRoot == .issues
                    && nav.linearIssuesTab == tab && !nav.showSettings,
                showTitle: showTitle
            ) {
                nav.showLinear(.issues)
                nav.linearIssuesTab = tab
            }
        }
        sidebarRow(
            title: l.linearProjectsTab,
            symbol: LinearChromeSymbol.project,
            indent: 1,
            selected: false,
            showTitle: showTitle
        ) {
            nav.showLinear(.projects)
        }
        ForEach(LinearProjectsTab.allCases, id: \.self) { tab in
            sidebarRow(
                title: tab.title(l),
                symbol: tab.symbol,
                indent: 2,
                selected: nav.tab == .linear && nav.linearRoot == .projects
                    && nav.linearProjectsTab == tab && !nav.showSettings,
                showTitle: showTitle
            ) {
                nav.showLinear(.projects)
                nav.linearProjectsTab = tab
            }
        }
        sidebarRow(
            title: l.linearInitiativesTab,
            symbol: LinearChromeSymbol.initiative,
            indent: 1,
            selected: false,
            showTitle: showTitle
        ) {
            nav.showLinear(.initiatives)
        }
        ForEach(LinearInitiativesTab.allCases, id: \.self) { tab in
            sidebarRow(
                title: tab.title(l),
                symbol: tab.symbol,
                indent: 2,
                selected: nav.tab == .linear && nav.linearRoot == .initiatives
                    && nav.linearInitiativesTab == tab && !nav.showSettings,
                showTitle: showTitle
            ) {
                nav.showLinear(.initiatives)
                nav.linearInitiativesTab = tab
            }
        }
    }

    @ViewBuilder
    private func collectionChildren(showTitle: Bool) -> some View {
        ForEach(CollectionSegment.allCases, id: \.self) { segment in
            sidebarRow(
                title: segment.title(l),
                symbol: segment.symbol,
                indent: 1,
                selected: nav.tab == .collection && nav.collectionSegment == segment && !nav.showSettings,
                showTitle: showTitle
            ) {
                nav.showSettings = false
                nav.showingCollectionLog = false
                nav.collectionSegment = segment
                nav.tab = .collection
            }
        }
    }

    private func hasSelectedChild(_ tab: PopoverTab) -> Bool {
        switch tab {
        case .linear, .collection: return !nav.showSettings && nav.tab == tab
        case .focus, .usage: return false
        }
    }

    private func sidebarRow(
        title: String,
        symbol: String,
        indent: Int,
        selected: Bool,
        showTitle: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .frame(width: 14)
                if showTitle {
                    Text(title)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(indent) * 12)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                selected ? Color(nsColor: MenuBarPanelMetrics.selectedFill) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .font(.system(size: 13, weight: selected ? .medium : .regular))
        .foregroundStyle(selected ? Color.primary : Color.secondary)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
