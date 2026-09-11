import Foundation

/// Passive companion XP + coins while the menu-bar app is open (refresh-driven).
///
/// Credits wall-clock time between ticks into growth (`eggUsage` / `applyUsage`) and coins,
/// without inflating `usedSinceInstall`.
enum TimeOpenXP {
    static let awardIntervalSeconds: TimeInterval = 10 * 60
    static let tokensPerAward = 5_000
    static let coinsPerAward = 1
    static let maxGapSeconds: TimeInterval = awardIntervalSeconds
    /// 6 hours of grants per local day (36 intervals).
    static let dailyCapIntervals = 36
    static let dailyCap = tokensPerAward * dailyCapIntervals

    struct Credit: Equatable, Sendable {
        var xp: Int
        var awardedToday: Int
        var day: String
        var awardedAt: Date

        var coins: Int { (xp / tokensPerAward) * coinsPerAward }
        var intervals: Int { xp / tokensPerAward }
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
            return Credit(xp: 0, awardedToday: awarded, day: dayKey, awardedAt: now)
        }
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
