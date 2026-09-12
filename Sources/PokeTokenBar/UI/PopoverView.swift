import AppKit
import SwiftUI

enum PopoverTab: Hashable, CaseIterable {
    case focus, linear, usage, collection

    var symbol: String {
        switch self {
        case .focus: return "target"
        case .linear: return "circle"
        case .usage: return "chart.bar"
        case .collection: return "square.grid.2x2"
        }
    }

    func title(_ l: L) -> String {
        switch self {
        case .focus: return l.focusTab
        case .linear: return l.linearTab
        case .usage: return l.usageTab
        case .collection: return l.collection
        }
    }
}

enum CollectionSegment: Hashable, CaseIterable {
    case bag, dex, shop
}

/// 팝오버 치수의 단일 소스. 자식이 쓸 수 있는 폭을 알아야 할 때 이 값을 쓴다 — 넘치는 자식이
/// 부모 폭을 부풀리므로 GeometryReader 로 재면 순환한다.
enum PopoverMetrics {
    static let width: CGFloat = 360
    static let padding: CGFloat = 14
    /// 이 폭을 넘는 자식은 팝오버 창에 좌우로 잘린다.
    static let contentWidth: CGFloat = width - padding * 2
}

/// Popover navigation (root tab / collection segment / settings).
/// NSHostingController used to keep @State across close; AppDelegate calls reset()
/// on each open so reopen always lands on Focus, never the previous tab or Settings.
@MainActor
@Observable
final class PopoverNavigation {
    var showSettings = false
    var tab: PopoverTab = .focus
    /// Dex vs catch-log inside Collection → Dex. Reset does not clear this.
    var showingCollectionLog = false
    /// Bag | Dex | Shop. Default Dex. Reset keeps the last segment; representative pick forces Dex.
    var collectionSegment: CollectionSegment = .dex
    /// 프로바이더 탭 선택 — reset() 대상이 아님(팝오버를 다시 열어도 보던 서비스 유지).
    var providerID: String?
    /// 설정을 열 때 고급 섹션을 펼친 채로 시작할지. 세션 키 행이 접힌 disclosure 안에 살아서,
    /// 그냥 설정만 열면 "만료됐다"를 보고 들어온 사용자가 고칠 입력란을 못 찾는다.
    var expandAdvancedOnOpen = false

    func reset() {
        showSettings = false
        expandAdvancedOnOpen = false
        tab = .focus
    }

    func showFocus() {
        showSettings = false
        tab = .focus
    }

    /// Linear pin: start (or switch) the session and reveal Focus. Does not open Today.
    func pinIssueFromLinear(_ issue: LinearIssueSummary, session: FocusSessionStore) {
        session.pin(issue, openDesk: false)
        showFocus()
    }

    /// 세션 키 만료 안내 → 그 키를 고칠 수 있는 유일한 화면으로 바로 보낸다.
    func openSessionKeySettings() {
        showSettings = true
        expandAdvancedOnOpen = true
    }

    /// Settings representative row deep-links into Collection → Dex (not Bag/Shop, not catch log).
    func openRepresentativeDex() {
        showSettings = false
        showingCollectionLog = false
        collectionSegment = .dex
        tab = .collection
    }
}

@MainActor
struct PopoverView: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(UpdateChecker.self) private var updater
    @Environment(PopoverNavigation.self) private var nav

    private var l: L { companion.l }

    var body: some View {
        // NOTE: 설정을 .sheet 로 띄우면 transient 팝오버가 닫힐 때 시트가 고아로 남아
        // 이후 팝오버의 모든 버튼 클릭을 차단할 수 있음 — 팝오버 내부 화면 전환으로 처리
        @Bindable var nav = nav
        Group {
            if nav.showSettings {
                SettingsView(
                    onClose: { nav.showSettings = false },
                    onChooseRepresentative: { nav.openRepresentativeDex() },
                    startExpanded: nav.expandAdvancedOnOpen
                )
                    .environment(store)
                    .environment(companion)
                    .environment(updater)
            } else {
                mainContent
            }
        }
        .frame(width: PopoverMetrics.width)
        .background { PopoverMaterialBackground().ignoresSafeArea() }
        .environment(\.locale, companion.language.displayLocale)
    }

    @ViewBuilder
    private var updateBanner: some View {
        if let update = updater.available, store.updateNotificationsEnabled {
            HStack(spacing: 8) {
                Text(l.updateAvailable(update.version, current: updater.currentVersion))
                    .font(.caption)
                Spacer()
                if updater.isUpdating {
                    Text(l.updating).font(.caption2).foregroundStyle(.secondary)
                    ProgressView().controlSize(.small)
                } else {
                    Button(l.updateButton) { updater.applyUpdate() }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    Button(l.updateLater) { updater.skipCurrent() }
                        .buttonStyle(.borderless).controlSize(.small).foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            updateBanner
            Group {
                switch nav.tab {
                case .focus:
                    FocusTabView()
                case .linear:
                    LinearIntegrationView(store: store)
                case .usage:
                    UsageTabView()
                case .collection:
                    CollectionTabView(store: companion, navigation: nav)
                }
            }
            PopoverBottomBar()
        }
        .padding(PopoverMetrics.padding)
    }
}

