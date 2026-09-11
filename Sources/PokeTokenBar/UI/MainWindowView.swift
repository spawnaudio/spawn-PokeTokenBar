import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: UsageStore
    private let companion: CompanionStore
    private let hub: WorkHub
    private let timer: FocusTimer
    private let updater: UpdateChecker
    var onOpenChange: ((Bool) -> Void)?

    init(store: UsageStore, companion: CompanionStore, hub: WorkHub, timer: FocusTimer, updater: UpdateChecker) {
        self.store = store
        self.companion = companion
        self.hub = hub
        self.timer = timer
        self.updater = updater
    }

    func show() {
        if window == nil {
            let root = MainWindowView()
                .environment(store)
                .environment(companion)
                .environment(hub)
                .environment(timer)
                .environment(updater)
            let hosting = NSHostingController(rootView: root)
            let w = NSWindow(contentViewController: hosting)
            w.title = "PokeTokenBar"
            w.setContentSize(NSSize(width: 720, height: 560))
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.delegate = self
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        onOpenChange?(true)
    }

    func windowWillClose(_ notification: Notification) {
        onOpenChange?(false)
        window = nil
    }
}

@MainActor
struct MainWindowView: View {
    @Environment(UsageStore.self) private var store
    @Environment(CompanionStore.self) private var companion
    @Environment(WorkHub.self) private var hub
    @Environment(FocusTimer.self) private var timer

    @State private var selectedProjectID: String?

    private var l: L { companion.l }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                CompanionHeader(store: companion)
                RewardToastView(companion: companion)
                HStack {
                    Text(l.spendableTokens)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(companion.availableCoins)")
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                    Spacer()
                    Text(l.completedTodayCount(hub.completedTodayCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                WorkInboxView(hub: hub, companion: companion, timer: timer, compact: false)
            }
            .padding(14)
            .frame(minWidth: 360)

            VStack(alignment: .leading, spacing: 10) {
                Text(l.projectsTitle)
                    .font(.callout.weight(.semibold))
                if hub.linearProjects.isEmpty {
                    Text(l.projectsEmpty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    List(hub.linearProjects, selection: $selectedProjectID) { project in
                        Text(project.name).tag(project.id)
                    }
                    .frame(minHeight: 120)
                }
                if let projectID = selectedProjectID {
                    let issues = hub.projectIssues[projectID] ?? []
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(issues) { item in
                                HStack {
                                    Text(item.title)
                                        .lineLimit(2)
                                    Spacer()
                                    if item.status != .completed {
                                        Button(l.markDone) {
                                            Task { await hub.complete(item, companion: companion) }
                                        }
                                        .controlSize(.small)
                                    }
                                }
                                .padding(6)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(14)
            .frame(minWidth: 280)
            .task {
                await hub.loadProjects()
            }
            .onChange(of: selectedProjectID) { _, id in
                guard let id else { return }
                Task { await hub.loadProjectIssues(id) }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .task {
            await hub.refreshAll(companion: companion)
        }
    }
}

@MainActor
struct RewardToastView: View {
    let companion: CompanionStore
    @State private var visible = false
    @State private var lastSeq = 0

    var body: some View {
        Group {
            if visible, companion.lastReward.xp > 0 || companion.lastReward.coins > 0 {
                Text(companion.l.rewardToast(xp: companion.lastReward.xp, coins: companion.lastReward.coins))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.18))
                    .clipShape(Capsule())
            }
        }
        .onChange(of: companion.lastRewardSeq) { _, seq in
            guard seq != lastSeq else { return }
            lastSeq = seq
            visible = true
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                visible = false
                companion.consumeLastReward()
            }
        }
    }
}
