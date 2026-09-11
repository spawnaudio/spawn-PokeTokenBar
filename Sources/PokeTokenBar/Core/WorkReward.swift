import Foundation

struct Reward: Equatable, Sendable {
    var xp: Int
    var coins: Int

    static let zero = Reward(xp: 0, coins: 0)

    static func + (lhs: Reward, rhs: Reward) -> Reward {
        Reward(xp: lhs.xp + rhs.xp, coins: lhs.coins + rhs.coins)
    }
}

/// XP + coin grants for completions and timed work. Pure; no I/O.
enum WorkReward {
    static let linearBase = Reward(xp: 40_000, coins: 12)
    static let reminderBase = Reward(xp: 20_000, coins: 8)
    static let calendarBase = Reward(xp: 15_000, coins: 5)
    static let nativeTaskBase = Reward(xp: 25_000, coins: 8)
    static let habitBase = Reward(xp: 18_000, coins: 6)
    static let goalIncrement = Reward(xp: 22_000, coins: 7)
    static let goalBonus = Reward(xp: 50_000, coins: 20)
    static let focusPerInterval = Reward(xp: 8_000, coins: 2)

    static func estimateFactor(_ estimate: Int?) -> Double {
        guard let estimate else { return 1.0 }
        switch estimate {
        case 1: return 1.0
        case 2: return 1.25
        case 3: return 1.5
        case 5: return 2.0
        case 8: return 3.0
        default: return min(1 + Double(estimate) / 4.0, 4)
        }
    }

    static func linearPriorityFactor(_ priority: Int?) -> Double {
        switch priority {
        case 1: return 1.5
        case 2: return 1.25
        case 3: return 1.0
        case 4: return 0.75
        default: return 1.0
        }
    }

    static func reminderPriorityFactor(_ priority: Int?) -> Double {
        guard let priority else { return 1.0 }
        if priority <= 1 { return 1.4 }
        if priority <= 5 { return 1.0 }
        return 0.75
    }

    static func forCompletion(_ item: WorkItem) -> Reward {
        switch item.source {
        case .linear:
            return scale(linearBase, estimateFactor(item.estimate) * linearPriorityFactor(item.priority))
        case .reminders:
            return scale(reminderBase, reminderPriorityFactor(item.priority))
        case .appleCalendar, .googleCalendar:
            return calendarBase
        case .native:
            switch item.kind {
            case .habit: return habitBase
            case .goal: return goalIncrement
            case .task, .routine, .event: return nativeTaskBase
            }
        }
    }

    static func forFocusIntervals(_ count: Int) -> Reward {
        guard count > 0 else { return .zero }
        return Reward(xp: focusPerInterval.xp * count, coins: focusPerInterval.coins * count)
    }

    static func scale(_ base: Reward, _ factor: Double) -> Reward {
        Reward(
            xp: Int((Double(base.xp) * factor).rounded()),
            coins: Int((Double(base.coins) * factor).rounded()))
    }
}
