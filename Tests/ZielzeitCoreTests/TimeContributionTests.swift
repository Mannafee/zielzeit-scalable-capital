import XCTest
@testable import ZielzeitCore

/// Converting a holding's gain into arrival date.
///
/// Assertions are about relationships rather than exact weeks wherever the answer
/// depends on the projection's compounding: a test that pinned "2.3 weeks" would
/// break on any change to the rate convention while saying nothing about whether
/// the conversion is right.
final class TimeContributionTests: XCTestCase {

    private let goal = 100_000.0
    private let rate = 0.06
    private let savings = 500.0

    private func holding(_ isin: String, cost: Double, valuation: Double) -> Holding {
        // Quantity of 1 keeps `averageCost` and `valuation` readable as the euro
        // figures the assertions are written in.
        Holding(
            isin: isin, name: "Example \(isin)", quantity: 1,
            averageCost: cost, quotePrice: valuation, valuation: valuation
        )
    }

    private func contributions(_ items: [Holding], goal: Double? = nil) -> TimeContributions {
        TimeContributions.make(
            holdings: HoldingsSnapshot(items: items),
            goal: goal ?? self.goal,
            annualRate: rate,
            monthlySavings: savings
        )
    }

    // MARK: - Direction and magnitude

    func testAGainPullsTheGoalForward() throws {
        let result = contributions([holding("IE00EXAMPLE01", cost: 800, valuation: 1000)])
        let weeks = try XCTUnwrap(result.items.first?.weeks)
        XCTAssertGreaterThan(weeks, 0)
    }

    /// Removing a loss brings the date *forward*, so a position that is down
    /// contributes negative weeks. The sign is the whole point of the chart.
    func testALossPushesTheGoalBack() throws {
        let result = contributions([holding("IE00EXAMPLE01", cost: 1200, valuation: 1000)])
        let weeks = try XCTUnwrap(result.items.first?.weeks)
        XCTAssertLessThan(weeks, 0)
    }

    func testABiggerGainIsWorthMoreWeeks() throws {
        let small = contributions([holding("IE00EXAMPLE01", cost: 900, valuation: 1000)])
        let large = contributions([holding("IE00EXAMPLE01", cost: 500, valuation: 1000)])
        XCTAssertGreaterThan(
            try XCTUnwrap(large.items.first?.weeks), try XCTUnwrap(small.items.first?.weeks)
        )
    }

    func testAPositionAtCostIsWorthNoTime() throws {
        let result = contributions([holding("IE00EXAMPLE01", cost: 1000, valuation: 1000)])
        XCTAssertEqual(try XCTUnwrap(result.items.first?.weeks), 0, accuracy: 1e-9)
    }

    // MARK: - Ranking and scaling

    func testRanksByContributionWithTheLargestFirst() {
        let result = contributions([
            holding("IE00EXAMPLE01", cost: 950, valuation: 1000),
            holding("IE00EXAMPLE02", cost: 500, valuation: 1000),
            holding("IE00EXAMPLE03", cost: 800, valuation: 1000),
        ])
        XCTAssertEqual(
            result.ranked.map(\.holding.isin),
            ["IE00EXAMPLE02", "IE00EXAMPLE03", "IE00EXAMPLE01"]
        )
    }

    func testPeakIsTheLargestMagnitudeSoBarsScaleToIt() throws {
        let result = contributions([
            holding("IE00EXAMPLE01", cost: 950, valuation: 1000),
            holding("IE00EXAMPLE02", cost: 500, valuation: 1000),
        ])
        let peak = try XCTUnwrap(result.peakWeeks)
        let largest = try XCTUnwrap(result.ranked.first?.weeks)
        XCTAssertEqual(peak, largest, accuracy: 1e-9)
    }

    /// A loss counts toward the scale by magnitude, or its bar would overflow the
    /// axis the gains were fitted to.
    func testPeakUsesMagnitudeSoLossesAreScaledToo() throws {
        let result = contributions([
            holding("IE00EXAMPLE01", cost: 990, valuation: 1000),
            holding("IE00EXAMPLE02", cost: 3000, valuation: 1000),
        ])
        let peak = try XCTUnwrap(result.peakWeeks)
        XCTAssertGreaterThan(peak, 0)
        XCTAssertEqual(peak, abs(try XCTUnwrap(result.items[1].weeks)), accuracy: 1e-9)
    }

    // MARK: - The total

    /// The headline is computed by removing every gain at once, not by adding the
    /// bars up: compounding is not additive, so the two differ and the headline is
    /// the one that answers "what is my gain worth".
    func testTotalIsComputedWholeRatherThanSummedFromTheBars() throws {
        let result = contributions([
            holding("IE00EXAMPLE01", cost: 600, valuation: 1000),
            holding("IE00EXAMPLE02", cost: 700, valuation: 1000),
            holding("IE00EXAMPLE03", cost: 800, valuation: 1000),
        ])
        let total = try XCTUnwrap(result.totalWeeks)
        let summed = result.items.compactMap(\.weeks).reduce(0, +)
        XCTAssertGreaterThan(total, 0)
        XCTAssertGreaterThan(total, try XCTUnwrap(result.peakWeeks))
        XCTAssertNotEqual(total, summed, accuracy: 1e-12)
    }

    // MARK: - Nothing to say

    func testNothingToShowOnceTheGoalIsReached() {
        let result = contributions(
            [holding("IE00EXAMPLE01", cost: 800, valuation: 1000)], goal: 500
        )
        XCTAssertTrue(result.isEmpty)
        XCTAssertNil(result.totalWeeks)
    }

    func testNothingToShowWithoutAnArrivalDate() {
        let result = TimeContributions.make(
            holdings: HoldingsSnapshot(items: [holding("IE00EXAMPLE01", cost: 800, valuation: 1000)]),
            goal: goal,
            annualRate: 0,
            monthlySavings: 0
        )
        XCTAssertTrue(result.isEmpty)
        XCTAssertNil(result.totalWeeks)
    }

    func testNoHoldingsIsEmptyRatherThanZero() {
        let result = contributions([])
        XCTAssertTrue(result.isEmpty)
    }
}
