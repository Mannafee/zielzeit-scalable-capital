import XCTest
@testable import ZielzeitCore

/// The holdings page as a whole: what it takes from the projection behind it, and
/// when it decides a position is worth pointing at.
final class HoldingsReportTests: XCTestCase {

    private func holding(_ isin: String, cost: Double, valuation: Double) -> Holding {
        Holding(
            isin: isin, name: "Example \(isin)", quantity: 1,
            averageCost: cost, quotePrice: valuation, valuation: valuation
        )
    }

    private func report(
        _ items: [Holding],
        goal: Double = 100_000
    ) -> HoldingsReport {
        HoldingsReport(
            holdings: HoldingsSnapshot(items: items),
            report: Report(
                goal: goal,
                snapshot: PortfolioSnapshot(total: 10_000, monthlySavings: 500),
                now: Date(timeIntervalSince1970: 1_786_000_000)
            )
        )
    }

    // MARK: - Composition

    /// The weeks on this page must be measured against the same year the popover
    /// behind it claims, which is why the rate is taken from the report rather than
    /// chosen here.
    func testTakesTheProjectionsOwnRateAndGoal() {
        let projection = Report(
            goal: 250_000,
            snapshot: PortfolioSnapshot(total: 10_000, monthlySavings: 500),
            now: Date(timeIntervalSince1970: 1_786_000_000)
        )
        let page = HoldingsReport(
            holdings: HoldingsSnapshot(items: [holding("IE00EXAMPLE01", cost: 800, valuation: 1000)]),
            report: projection
        )
        XCTAssertEqual(page.annualRate, projection.headlineRate)
        XCTAssertEqual(page.goal, 250_000)
    }

    func testContributionsAreDerivedForEveryPosition() {
        let page = report([
            holding("IE00EXAMPLE01", cost: 800, valuation: 1000),
            holding("IE00EXAMPLE02", cost: 900, valuation: 1000),
        ])
        XCTAssertEqual(page.contributions.items.count, 2)
        XCTAssertFalse(page.isEmpty)
    }

    func testNoPositionsIsAnEmptyPage() {
        XCTAssertTrue(report([]).isEmpty)
    }

    // MARK: - The outlier

    /// Ten points from the portfolio's own return is the bar. Below it, a spread of
    /// returns is just what a portfolio of different funds looks like.
    func testAPositionFarFromTheAverageIsMarked() throws {
        let page = report([
            holding("IE00EXAMPLE01", cost: 800, valuation: 1000),
            holding("IE00EXAMPLE02", cost: 790, valuation: 1000),
            holding("IE00EXAMPLE03", cost: 995, valuation: 1000),
        ])
        XCTAssertEqual(try XCTUnwrap(page.outlier).isin, "IE00EXAMPLE03")
    }

    func testNothingIsMarkedWhenTheReturnsAreClose() {
        let page = report([
            holding("IE00EXAMPLE01", cost: 800, valuation: 1000),
            holding("IE00EXAMPLE02", cost: 810, valuation: 1000),
            holding("IE00EXAMPLE03", cost: 805, valuation: 1000),
        ])
        XCTAssertNil(page.outlier)
    }

    /// A single holding *is* the portfolio, so its return cannot differ from the
    /// average and there is no outlier to find.
    func testASinglePositionIsNeverItsOwnOutlier() {
        XCTAssertNil(report([holding("IE00EXAMPLE01", cost: 500, valuation: 1000)]).outlier)
    }

    func testPositionsWithoutACostBasisCannotBeTheOutlier() {
        let page = report([
            holding("IE00EXAMPLE01", cost: 800, valuation: 1000),
            holding("IE00EXAMPLE02", cost: 0, valuation: 1000),
        ])
        XCTAssertNotEqual(page.outlier?.isin, "IE00EXAMPLE02")
    }
}
