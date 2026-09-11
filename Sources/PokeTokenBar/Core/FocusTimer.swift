import Foundation
import Observation

@MainActor
@Observable
final class FocusTimer {
    static let defaultDuration: TimeInterval = 25 * 60

    var assignedItemID: UUID?
    var duration: TimeInterval
    var remaining: TimeInterval
    var isRunning = false
    private(set) var awardedIntervals = 0
    private var elapsed: TimeInterval = 0
    private var lastTick: Date?
    private var ticker: Timer?
    weak var companion: CompanionStore?

    init(duration: TimeInterval = FocusTimer.defaultDuration) {
        self.duration = duration
        self.remaining = duration
    }

    var remainingText: String? {
        guard assignedItemID != nil || isRunning || remaining < duration else { return nil }
        let total = max(0, Int(remaining.rounded(.up)))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    func assign(_ item: WorkItem, duration: TimeInterval = FocusTimer.defaultDuration) {
        assignedItemID = item.id
        self.duration = duration
        remaining = duration
        elapsed = 0
        awardedIntervals = 0
        lastTick = nil
        isRunning = false
    }

    func start(now: Date = Date()) {
        guard remaining > 0 else { return }
        isRunning = true
        lastTick = now
        startTicker()
    }

    func pause() {
        isRunning = false
        lastTick = nil
        stopTicker()
    }

    func reset() {
        pause()
        remaining = duration
        elapsed = 0
        awardedIntervals = 0
    }

    func clear() {
        pause()
        assignedItemID = nil
        remaining = duration
        elapsed = 0
        awardedIntervals = 0
    }

    /// Credits 10-minute focus intervals. Driven by the app refresh loop (not a dedicated Timer).
    @discardableResult
    func tick(now: Date = Date(), companion: CompanionStore) -> Int {
        guard isRunning, let last = lastTick else { return 0 }
        let delta = now.timeIntervalSince(last)
        lastTick = now
        elapsed += delta
        remaining = max(0, remaining - delta)
        let intervals = Int(elapsed / TimeOpenXP.awardIntervalSeconds)
        let fresh = max(0, intervals - awardedIntervals)
        if fresh > 0 {
            awardedIntervals = intervals
            _ = companion.credit(WorkReward.forFocusIntervals(fresh))
        }
        if remaining <= 0 {
            pause()
            remaining = 0
        }
        return fresh
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let companion = self.companion else { return }
                _ = self.tick(companion: companion)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
