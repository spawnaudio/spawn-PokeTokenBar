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

/// Opaque card: 12pt continuous corners + hairline. Lists stay off Tahoe glass.
@MainActor
struct PopoverCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
    }
}

/// Primary / secondary / toolbar buttons. macOS 26+ uses Liquid Glass; older
/// macOS keeps bordered / borderless so the popover still reads as a control.
enum TahoeButtonKind {
    case prominent
    case regular
    case accessory
}

/// Morphing glass cluster. Older macOS just lays out the children.
@MainActor
struct TahoeGlassCluster<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension View {
    func popoverCard() -> some View {
        modifier(PopoverCardModifier())
    }

    /// Quiet bordered pill for menus/dropdowns (Linear chip, not glass).
    func linearChipChrome(expands: Bool = false) -> some View {
        self
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: expands ? .infinity : nil, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
            }
    }

    /// Quiet segmented item: selected is a filled pill, idle has no chrome.
    func linearSegmentChrome(selected: Bool) -> some View {
        self
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(selected ? Color.primary.opacity(0.12) : Color.clear, in: Capsule())
    }

    /// Tahoe glass on the bottom tab strip only. Older macOS keeps an ultra-thin material bar.
    @ViewBuilder
    func popoverBottomBarChrome() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// `.glass` / `.glassProminent` on Tahoe; bordered or borderless below macOS 26.
    @ViewBuilder
    func tahoeButtonStyle(_ kind: TahoeButtonKind) -> some View {
        if #available(macOS 26, *) {
            switch kind {
            case .prominent:
                self.buttonStyle(.glassProminent)
            case .regular, .accessory:
                self.buttonStyle(.glass)
            }
        } else {
            switch kind {
            case .prominent:
                self.buttonStyle(.borderedProminent)
            case .regular:
                self.buttonStyle(.bordered)
            case .accessory:
                self.buttonStyle(.borderless)
            }
        }
    }

    /// Overlay island / prompt chrome: glass on Tahoe, opaque window fill elsewhere.
    @ViewBuilder
    func tahoeFloatingChrome(cornerRadius: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(Color(nsColor: .windowBackgroundColor).opacity(0.95), in: shape)
        }
    }

    @ViewBuilder
    func tahoePromptChrome(cornerRadius: CGFloat = 10) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(Color(nsColor: .windowBackgroundColor), in: shape)
        }
    }
}

enum TahoeChromeSymbol {
    /// Trailing menu affordance on popup chips.
    static let menuChevron = "chevron.down"
}

/// Quiet popup label: current value plus a trailing chevron (Linear chip, not glass).
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
        }
        .menuIndicator(.hidden)
        .linearChipChrome(expands: expands)
        .controlSize(size)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(selectionTitle)
    }
}

struct TahoeTabItem<Value: Hashable> {
    let value: Value
    let title: String
    var symbol: String? = nil

    init(_ value: Value, title: String, symbol: String? = nil) {
        self.value = value
        self.title = title
        self.symbol = symbol
    }
}

/// Selected = filled quiet pill, idle = no fill. Not Tahoe glass.
@MainActor
struct TahoeTabBar<Value: Hashable>: View {
    @Binding var selection: Value
    var size: ControlSize = .small
    let items: [TahoeTabItem<Value>]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.value) { item in
                let selected = selection == item.value
                Button {
                    selection = item.value
                } label: {
                    if let symbol = item.symbol {
                        Label(item.title, systemImage: symbol)
                    } else {
                        Text(item.title)
                    }
                }
                .font(.caption.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .linearSegmentChrome(selected: selected)
                .controlSize(size)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// 24–28pt metadata pill: quiet border, no glass.
@MainActor
struct LinearTagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay {
                Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
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
                Capsule().fill(Color.primary.opacity(0.08))
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
            Label(paused ? resumeTitle : pauseTitle,
                  systemImage: paused ? "play.fill" : "pause.fill")
        }
        .tahoeButtonStyle(.prominent)
        .controlSize(.regular)
        .disabled(disabled)
        .help(paused ? resumeTitle : pauseTitle)
    }
}

/// Tahoe glass on Mark done (Today / Focus primary). Lists stay opaque.
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
struct PopoverBottomBar: View {
    @Environment(PopoverNavigation.self) private var nav
    @Environment(FocusSessionStore.self) private var session
    @Environment(CompanionStore.self) private var companion

    private var l: L { companion.l }

    var body: some View {
        @Bindable var nav = nav
        TahoeGlassCluster(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(PopoverTab.allCases, id: \.self) { tab in
                        Button {
                            nav.tab = tab
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tab.symbol)
                                    .font(.body)
                                    .symbolVariant(nav.tab == tab ? .fill : .none)
                                Text(tab.title(l))
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(nav.tab == tab ? Color.accentColor : Color.secondary)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tab.title(l))
                        .accessibilityAddTraits(nav.tab == tab ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .popoverBottomBarChrome()

                iconButton(systemName: "calendar", help: l.todayDeskMenuOpen, label: l.todayDeskWindowTitle) {
                    session.openDesk()
                }
                iconButton(systemName: "gearshape", help: l.settings, label: l.settings) {
                    nav.showSettings = true
                }
            }
        }
    }

    private func iconButton(systemName: String, help: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .tahoeButtonStyle(.accessory)
        .buttonBorderShape(.circle)
        .controlSize(.regular)
        .help(help)
        .accessibilityLabel(label)
    }
}
