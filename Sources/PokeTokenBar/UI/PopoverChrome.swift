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
    static let idle = Color.primary.opacity(0.14)
    static let selected = Color.primary.opacity(0.18)

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
                    .fill(Color.primary.opacity(0.06))
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
            .background((tint?.opacity(0.16) ?? Color.primary.opacity(0.06)), in: Capsule())
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
            .background(selected ? Color.primary.opacity(0.14) : Color.clear, in: Capsule())
            .overlay {
                Capsule().strokeBorder(
                    selected ? TahoeHairline.selected : TahoeHairline.idle,
                    lineWidth: TahoeHairline.width)
            }
    }

    /// Toolbar strip: filled control surface + hairline.
    func popoverBottomBarChrome() -> some View {
        self
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .background(Color.primary.opacity(0.16), in: Capsule())
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
            .background(Color.primary.opacity(0.08), in: shape)
            .overlay { shape.strokeBorder(TahoeHairline.idle, lineWidth: TahoeHairline.width) }
    }

    func tahoePromptChrome(cornerRadius: CGFloat = 10) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Color.primary.opacity(0.08), in: shape)
            .overlay { shape.strokeBorder(TahoeHairline.idle, lineWidth: TahoeHairline.width) }
    }

    func tahoeIconChrome(selected: Bool = false) -> some View {
        self
            .background(
                selected ? Color.primary.opacity(0.14) : Color.clear,
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
            .background((tint?.opacity(0.16) ?? Color.primary.opacity(0.06)), in: Capsule())
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
                    .fill(Color.primary.opacity(0.08))
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
struct PopoverShellToolbar: View {
    @Environment(PopoverNavigation.self) private var nav
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion
    @Environment(UsageStore.self) private var store

    private var l: L { companion.l }

    var body: some View {
        @Bindable var nav = nav
        HStack(spacing: 8) {
            if nav.canGoBack {
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

            ViewThatFits(in: .horizontal) {
                tabRow(showTitle: true)
                    .fixedSize(horizontal: true, vertical: false)
                tabRow(showTitle: false)
            }
            Spacer(minLength: 8)

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
            iconButton(systemName: "gearshape", help: l.settings, label: l.settings, selected: nav.showSettings) {
                nav.showSettings = true
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
                        selected ? Color.primary.opacity(0.12) : Color.clear,
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
