import XCTest
@testable import PokeTokenBar

/// Time-open XP through CompanionStore.update (refresh path).
@MainActor
final class TimeOpenCompanionTests: XCTestCase {
    private final class ClockBox: @unchecked Sendable {
        nonisolated(unsafe) var now: Date
        init(_ d: Date) { now = d }
    }

    private let day = "2026-09-06"
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private var sampleLine: EvoLine {
        EvoLine(
            baseID: 1,
            tree: EvoNode(speciesID: 1, children: [
                EvoNode(speciesID: 2, children: [EvoNode(speciesID: 3, children: [])])
            ]),
            rarity: .common,
            names: [:])
    }

    private func makeStore(clock: ClockBox) -> CompanionStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("time-open-\(UUID().uuidString).json")
        return CompanionStore(
            provider: StubProvider(value: sampleLine),
            clock: { clock.now },
            fileURL: url,
            rng: SeededRNG(seed: 1))
    }

    func testOpenTimeCreditsEggWithoutInflatingUsedSinceInstall() {
        let clock = ClockBox(t0)
        let store = makeStore(clock: clock)

        store.update(
            todayTokensByProvider: ["test": 0],
            todayDate: day,
            monthTotal: 0,
            burnTier: .idle,
            limitWarning: false,
            hasUsageData: true)
        XCTAssertEqual(store.state.eggUsage, 0, "first tick seeds only")
        XCTAssertEqual(store.state.usedSinceInstall, 0)
        XCTAssertNotNil(store.state.lastTimeOpenAwardAt)

        clock.now = t0.addingTimeInterval(120)
        store.update(
            todayTokensByProvider: ["test": 0],
            todayDate: day,
            monthTotal: 0,
            burnTier: .idle,
            limitWarning: false,
            hasUsageData: true)

        XCTAssertEqual(store.state.eggUsage, TimeOpenXP.tokensPerMinute * 2)
        XCTAssertEqual(store.state.usedSinceInstall, 0,
                       "time XP must not inflate shop/usage totals")
    }

    func testDisabledClearsBaselineWithoutAwarding() {
        let clock = ClockBox(t0)
        let store = makeStore(clock: clock)
        store.awardTimeOpenXP(today: day, enabled: true)
        XCTAssertNotNil(store.state.lastTimeOpenAwardAt)

        clock.now = t0.addingTimeInterval(60)
        store.awardTimeOpenXP(today: day, enabled: false)
        XCTAssertNil(store.state.lastTimeOpenAwardAt)
        XCTAssertEqual(store.state.eggUsage, 0)
    }
}
