import Foundation

/// Passive companion XP while the menu-bar app is open (refresh-driven).
///
/// Credits wall-clock time between `CompanionStore.update` ticks into the same growth
/// meter as token usage (`eggUsage` / `applyUsage`), without inflating `usedSinceInstall`
/// (shop wallet / real-usage stats stay usage-only — same rule as Rare Candy).
enum TimeOpenXP {
    /// Tokens per minute of credited open time.
    /// ~600k/hour → ~4.8M per 8h workday (just under one egg hatch at 5M).
    static let tokensPerMinute = 10_000
    /// Cap credited gap so sleep/wake does not dump hours of AFK XP in one tick.
    static let maxGapSeconds: TimeInterval = 5 * 60
    /// Per calendar-day cap (local `yyyy-MM-dd`) so idle open cannot outpace real usage forever.
    static let dailyCap = 5_000_000

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
        let elapsed = now.timeIntervalSince(last)
        guard elapsed > 0 else {
            return Credit(xp: 0, awardedToday: awarded, day: dayKey, awardedAt: last)
        }
        guard awarded < dailyCap else {
            return Credit(xp: 0, awardedToday: awarded, day: dayKey, awardedAt: now)
        }
        let creditedSeconds = min(elapsed, maxGapSeconds)
        let raw = Int((creditedSeconds / 60.0) * Double(tokensPerMinute))
        let xp = min(max(0, raw), dailyCap - awarded)
        return Credit(xp: xp, awardedToday: awarded + xp, day: dayKey, awardedAt: now)
    }
}
