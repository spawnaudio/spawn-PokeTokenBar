import Foundation

/// Fork-only economy knob. Official PokeTokenBar is `1.0`.
///
/// Keep this file (and the `EconomyScale.tokens` call sites) when merging `upstream/main`.
/// If upstream changes a price, take *their* integer and leave the `tokens(...)` wrap.
enum EconomyScale {
    /// 0.01 = 1% of official hatch / evolve / shop token costs.
    static let factor: Double = 0.01

    static func tokens(_ upstream: Int) -> Int {
        Int((Double(upstream) * factor).rounded())
    }
}
