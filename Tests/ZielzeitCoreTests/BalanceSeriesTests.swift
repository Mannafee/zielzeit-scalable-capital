import XCTest
@testable import ZielzeitCore

/// The chart draws from these series, so they must agree with the closed-form
/// `monthsToGoal` the headline uses. If they ever disagree, the chart and the
/// projected year would tell the user different stories.
final class BalanceSeriesTests: XCTestCase {

    private let value = 12_480.50
    private let savings = 380.0
    private let goal = 100_000.0

    // MARK: - Balance

    func testBalanceAtMonthZeroIsTheCurrentValue() {
        XCTAssertEqual(
            Projection.balance(value: value, monthlyRate: 0.005, monthlySavings: savings, afterMonths: 0),
            value
        )
    }

    func testBalanceMatchesStepwiseSimulation() {
        let r = Projection.monthlyRate(annual: 0.06)
        var simulated = value
        for _ in 0..<36 { simulated = simulated * (1 + r) + savings }

        let closedForm = Projection.balance(value: value, monthlyRate: r, monthlySavings: savings, afterMonths: 36)
        XCTAssertEqual(closedForm, simulated, accuracy: 0.01)
    }

    func testBalanceWithZeroRateIsLinear() {
        XCTAssertEqual(
            Projection.balance(value: 1_000, monthlyRate: 0, monthlySavings: 100, afterMonths: 10),
            2_000
        )
    }

    // MARK: - Series

    func testSeriesStartsAtTheCurrentValue() throws {
        let series = Projection.balanceSeries(
            value: value, monthlyRate: 0.005, monthlySavings: savings, months: 120
        )
        let first = try XCTUnwrap(series.first)
        XCTAssertEqual(first.month, 0)
        XCTAssertEqual(first.balance, value)
    }

    func testSeriesIsMonotonicWhileGrowing() throws {
        let series = Projection.balanceSeries(
            value: value, monthlyRate: Projection.monthlyRate(annual: 0.06),
            monthlySavings: savings, months: 240
        )
        for (earlier, later) in zip(series, series.dropFirst()) {
            XCTAssertGreaterThan(later.balance, earlier.balance)
            XCTAssertGreaterThan(later.month, earlier.month)
        }
    }

    func testSeriesReachesTheHorizonEvenWhenThinned() throws {
        let series = Projection.balanceSeries(
            value: value, monthlyRate: 0.001, monthlySavings: savings, months: 500, step: 7
        )
        // A step that does not divide the horizon evenly must still land on it,
        // otherwise the curve would visibly stop short of the axis edge.
        XCTAssertEqual(series.last?.month, 500)
    }

    func testCeilingStopsTheCurveExactlyOnTheGoal() throws {
        let series = Projection.balanceSeries(
            value: value,
            monthlyRate: Projection.monthlyRate(annual: 0.24),
            monthlySavings: savings,
            months: 480,
            ceiling: goal
        )
        let last = try XCTUnwrap(series.last)
        XCTAssertEqual(last.balance, goal)
        // Nothing may overshoot the goal line.
        XCTAssertTrue(series.allSatisfy { $0.balance <= goal })
    }

    /// The cross-check that matters: where the curve meets the goal must be the
    /// month the headline projection reports — exactly, not to within a sample.
    func testSeriesCrossesTheGoalAtTheProjectedMonth() throws {
        let r = Projection.monthlyRate(annual: Report.moderateRate)
        let expected = try XCTUnwrap(
            Projection.monthsToGoal(value: value, goal: goal, monthlyRate: r, monthlySavings: savings)
        )
        let series = Projection.balanceSeries(
            value: value, monthlyRate: r, monthlySavings: savings, months: 600, ceiling: goal
        )
        XCTAssertEqual(try XCTUnwrap(series.last).month, expected, accuracy: 1e-9)
    }

    /// The crossing is solved, not sampled. A thinned series must land on the same
    /// month a dense one does: the last point is what a chart draws its arrival dot
    /// on, beside a year taken from the exact projection, so a sample-sized gap
    /// between them shows as a dot sitting past its own label.
    func testThinnedSeriesStillCrossesAtTheExactMonth() throws {
        let r = Projection.monthlyRate(annual: Report.moderateRate)
        let dense = try XCTUnwrap(
            Projection.balanceSeries(
                value: value, monthlyRate: r, monthlySavings: savings,
                months: 600, step: 1, ceiling: goal
            ).last
        )
        for step in [4, 7, 13, 60] {
            let thinned = try XCTUnwrap(
                Projection.balanceSeries(
                    value: value, monthlyRate: r, monthlySavings: savings,
                    months: 600, step: step, ceiling: goal
                ).last
            )
            XCTAssertEqual(thinned.month, dense.month, accuracy: 1e-9, "step \(step)")
            XCTAssertEqual(thinned.balance, goal, "step \(step)")
        }
    }

    /// Dynamization walks the balance in twelve-month blocks, so the crossing has
    /// to come from the same walk rather than from the flat closed form.
    func testCrossingMatchesTheProjectionUnderDynamization() throws {
        let r = Projection.monthlyRate(annual: Report.moderateRate)
        let expected = try XCTUnwrap(
            Projection.monthsToGoal(
                value: value, goal: goal, monthlyRate: r,
                monthlySavings: savings, dynamizationRate: 0.05
            )
        )
        let series = Projection.balanceSeries(
            value: value, monthlyRate: r, monthlySavings: savings,
            months: 600, step: 5, ceiling: goal, dynamizationRate: 0.05
        )
        XCTAssertEqual(try XCTUnwrap(series.last).month, expected, accuracy: 1e-9)
    }

    // MARK: - Report curves

    private func report(extra: Double = 0) -> Report {
        Report(
            goal: goal,
            snapshot: PortfolioSnapshot(
                total: value, oneYearGain: 1_950.0, monthlySavings: savings, savingsPlanCount: 4
            )
        )
    }

    func testOneCurvePerDerivableScenario() {
        XCTAssertEqual(report().curves().map(\.label), ["Cautious", "Moderate", "Your pace"])
    }

    func testCurvesOmitAScenarioWithNoRate() {
        // No derivable realized rate, so only the two fixed scenarios plot.
        let young = PortfolioSnapshot(total: 3_000, oneYearGain: 50, monthlySavings: 1_000)
        let curves = Report(goal: goal, snapshot: young).curves()
        XCTAssertEqual(curves.map(\.label), ["Cautious", "Moderate"])
    }

    func testEveryCurveEndsOnTheGoalWhenItArrives() throws {
        for curve in report().curves() {
            let last = try XCTUnwrap(curve.points.last)
            XCTAssertTrue(curve.reachesGoal, curve.label)
            XCTAssertEqual(last.balance, goal, accuracy: 0.01, curve.label)
        }
    }

    /// The invariant the chart depends on: the point it draws the arrival dot on
    /// and the figure it takes the annotated year from are the same month.
    func testEveryCurveEndsOnItsOwnArrivalMonth() throws {
        for curve in report(extra: 350).curves(extraMonthlySavings: 350) {
            let arrival = try XCTUnwrap(curve.arrivalMonths, curve.label)
            XCTAssertEqual(try XCTUnwrap(curve.points.last).month, arrival, accuracy: 1e-9, curve.label)
        }
    }

    func testFasterScenariosReachTheGoalInFewerMonths() throws {
        let curves = report().curves()
        let cautious = try XCTUnwrap(curves.first { $0.label == "Cautious" }?.arrivalMonths)
        let moderate = try XCTUnwrap(curves.first { $0.label == "Moderate" }?.arrivalMonths)
        let yourPace = try XCTUnwrap(curves.first { $0.label == "Your pace" }?.arrivalMonths)
        XCTAssertGreaterThan(cautious, moderate)
        XCTAssertGreaterThan(moderate, yourPace)
    }

    func testHorizonShrinksAsSavingsIncrease() {
        let base = report().chartHorizonMonths()
        let boosted = report().chartHorizonMonths(extraMonthlySavings: 500)
        XCTAssertLessThan(boosted, base)
    }

    func testHorizonCoversTheSlowestArrival() throws {
        let report = self.report()
        let horizon = Double(report.chartHorizonMonths())
        let slowest = try XCTUnwrap(report.curves().compactMap(\.arrivalMonths).max())
        XCTAssertGreaterThanOrEqual(horizon, slowest)
    }

    func testCurvesStayWithinAReasonablePointCount() {
        // The chart is ~340pt wide; thousands of samples would be wasted work.
        for curve in report().curves() {
            XCTAssertLessThanOrEqual(curve.points.count, 200, curve.label)
            XCTAssertGreaterThan(curve.points.count, 10, curve.label)
        }
    }

    // MARK: - Slider support

    func testArrivalImprovesWithExtraSavings() throws {
        let report = self.report()
        let base = try XCTUnwrap(report.arrival(extraMonthlySavings: 0).months)
        let boosted = try XCTUnwrap(report.arrival(extraMonthlySavings: 200).months)
        XCTAssertLessThan(boosted, base)
        XCTAssertGreaterThan(try XCTUnwrap(report.arrival(extraMonthlySavings: 200).yearsSaved), 0)
    }

    func testArrivalWithNoExtraMatchesTheHeadline() {
        let report = self.report()
        XCTAssertEqual(report.arrival(extraMonthlySavings: 0).year, report.headlineYear)
    }

    func testArrivalAgreesWithTheFixedWhatIfRows() throws {
        let report = self.report()
        for whatIf in report.whatIfs {
            let continuous = report.arrival(extraMonthlySavings: whatIf.extraPerMonth)
            XCTAssertEqual(continuous.year, whatIf.year, "at +\(whatIf.extraPerMonth)")
        }
    }

    func testUnreachableGoalYieldsNoCurvePointsAtTheGoal() {
        // A stalled portfolio at a huge goal: the slider must be able to render
        // an empty/never state rather than collapsing.
        let stalled = PortfolioSnapshot(total: 100, oneYearGain: 0, monthlySavings: 0)
        let report = Report(goal: 50_000_000, snapshot: stalled)
        XCTAssertNil(report.arrival(extraMonthlySavings: 0).months)
        XCTAssertTrue(report.curves().allSatisfy { !$0.reachesGoal })
    }
}
