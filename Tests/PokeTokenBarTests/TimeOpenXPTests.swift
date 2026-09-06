import XCTest
@testable import PokeTokenBar

final class TimeOpenXPTests: XCTestCase {
    private let day = "2026-09-06"
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testFirstTickSeedsWithoutXP() {
        let credit = TimeOpenXP.credit(
            now: t0, day: day, lastAwardAt: nil, awardDay: "", awardedToday: 0)
        XCTAssertEqual(credit.xp, 0)
        XCTAssertEqual(credit.awardedAt, t0)
        XCTAssertEqual(credit.day, day)
        XCTAssertEqual(credit.awardedToday, 0)
    }

    func testOneMinuteAwardsTokensPerMinute() {
        let credit = TimeOpenXP.credit(
            now: t0.addingTimeInterval(60),
            day: day,
            lastAwardAt: t0,
            awardDay: day,
            awardedToday: 0)
        XCTAssertEqual(credit.xp, TimeOpenXP.tokensPerMinute)
        XCTAssertEqual(credit.awardedToday, TimeOpenXP.tokensPerMinute)
    }

    func testGapIsCappedAtMaxGapSeconds() {
        let credit = TimeOpenXP.credit(
            now: t0.addingTimeInterval(3_600),
            day: day,
            lastAwardAt: t0,
            awardDay: day,
            awardedToday: 0)
        let expected = Int((TimeOpenXP.maxGapSeconds / 60.0) * Double(TimeOpenXP.tokensPerMinute))
        XCTAssertEqual(credit.xp, expected)
    }

    func testDailyCapStopsFurtherAwards() {
        let almost = TimeOpenXP.dailyCap - 100
        let credit = TimeOpenXP.credit(
            now: t0.addingTimeInterval(60),
            day: day,
            lastAwardAt: t0,
            awardDay: day,
            awardedToday: almost)
        XCTAssertEqual(credit.xp, 100)
        XCTAssertEqual(credit.awardedToday, TimeOpenXP.dailyCap)

        let next = TimeOpenXP.credit(
            now: t0.addingTimeInterval(120),
            day: day,
            lastAwardAt: credit.awardedAt,
            awardDay: day,
            awardedToday: credit.awardedToday)
        XCTAssertEqual(next.xp, 0)
        XCTAssertEqual(next.awardedToday, TimeOpenXP.dailyCap)
    }

    func testNewDayResetsDailyCounter() {
        let credit = TimeOpenXP.credit(
            now: t0.addingTimeInterval(60),
            day: "2026-09-07",
            lastAwardAt: t0,
            awardDay: day,
            awardedToday: TimeOpenXP.dailyCap)
        XCTAssertEqual(credit.day, "2026-09-07")
        XCTAssertEqual(credit.xp, TimeOpenXP.tokensPerMinute)
        XCTAssertEqual(credit.awardedToday, TimeOpenXP.tokensPerMinute)
    }
}
