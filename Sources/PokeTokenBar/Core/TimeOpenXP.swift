import Foundation

/// Passive companion XP while the menu-bar app is open (refresh-driven).
///
/// Credits wall-clock time between `CompanionStore.update` ticks into the same growth
/// meter as token usage (`eggUsage` / `applyUsage`), without inflating `usedSinceInstall`
/// (shop wallet / real-usage stats stay usage-only — same rule as Rare Candy).
enum TimeOpenXP {
    /// Reward cadence: +1M growth XP every 10 minutes of active open time.
    static let awardIntervalSeconds: TimeInterval = 10 * 60
    static let tokensPerAward = 1_000_000
    /// Cap catch-up so wake from sleep cannot dump hours of AFK XP at once.
    /// We keep only one interval worth of backlog.
    static let maxGapSeconds: TimeInterval = awardIntervalSeconds
    /// Per calendar-day cap (local `yyyy-MM-dd`) so idle open cannot outpace usage forever.
    /// 144 intervals/day × 1M.
    static let dailyCap = tokensPerAward * 144

    struct Credit: Equatable, Sendable {
        var xp: Int
        var awardedToday: Int
        var day: String
        var awardedAt: Date
    }

    /// Pure credit calculation — no I/O. `nil` is never returned; callers always persist the
    /// returned timestamp so the next tick has a baseline (first tick / day roll / cap hit).
    static func credit(
        now: Date,
        day: String,
        lastAwardAt: Date?,
        awardDay: String,
        awardedToday: Int
    ) -> Credit {
        var awarded = awardedToday
        var dayKey = awardDay
        if dayKey != day {
            awarded = 0
            dayKey = day
        }
        guard let last = lastAwardAt else {
            // Seed only — avoid a huge catch-up grant on first enable / upgrade / import.
            return Credit(xp: 0, awardedToday: awarded, day: dayKey, awardedAt: now)
        }
        // Drop backlog older than maxGap so sleep/wake doesn't leak hours of AFK credit.
        let effectiveLast = max(last, now.addingTimeInterval(-maxGapSeconds))
        let elapsed = now.timeIntervalSince(effectiveLast)
        guard elapsed > 0 else {
            return Credit(xp: 0, awardedToday: awarded, day: dayKey, awardedAt: effectiveLast)
        }
        guard awarded < dailyCap else {
            return Credit(xp: 0, awardedToday: awarded, day: dayKey, awardedAt: now)
        }
        let awards = Int(elapsed / awardIntervalSeconds)
        guard awards > 0 else {
            return Credit(xp: 0, awardedToday: awarded, day: dayKey, awardedAt: effectiveLast)
        }
        let raw = awards * tokensPerAward
        let xp = min(raw, dailyCap - awarded)
        let creditedIntervals = xp / tokensPerAward
        let awardedAt = effectiveLast.addingTimeInterval(Double(creditedIntervals) * awardIntervalSeconds)
        return Credit(xp: xp, awardedToday: awarded + xp, day: dayKey, awardedAt: awardedAt)
    }
}
