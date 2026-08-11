import XCTest
@testable import ZielzeitCore

final class ProjectionTests: XCTestCase {

    // MARK: - Rate estimation

    func testSimpleDietzMatchesHandCalculation() {
        // Synthetic figures shaped like a real `sc broker overview` /
        // `sc broker savings-plans` pair.
        // base = 12480.50 − 1950.0 − (380.0 × 12)/2 = 8250.50
        let rate = Projection.realizedAnnualRate(
            total: 12_480.50,
            oneYearGain: 1_950.0,
            monthlySavings: 380.0
        )
        XCTAssertEqual(try XCTUnwrap(rate), 1_950.0 / 8_250.50, accuracy: 1e-9)
    }

    func testRateIsClampedOnTheUpside() {
        // A tiny portfolio that doubled would otherwise extrapolate absurdly.
        let rate = Projection.realizedAnnualRate(total: 2_000, oneYearGain: 1_000, monthlySavings: 0)
        XCTAssertEqual(try XCTUnwrap(rate), Projection.rateClamp)
    }

    func testRateIsClampedOnTheDownside() {
        let rate = Projection.realizedAnnualRate(total: 1_000, oneYearGain: -900, monthlySavings: 0)
        XCTAssertEqual(try XCTUnwrap(rate), -Projection.rateClamp)
    }

    func testNoRateWithoutAOneYearFigure() {
        XCTAssertNil(Projection.realizedAnnualRate(total: 10_000, oneYearGain: nil, monthlySavings: 100))
    }

    func testNoRateWhenContributionsSwampTheCapitalBase() {
        // A portfolio a few months old: value is almost entirely deposits, so
        // the Dietz denominator goes negative and the rate is meaningless.
        XCTAssertNil(Projection.realizedAnnualRate(total: 3_000, oneYearGain: 50, monthlySavings: 1_000))
    }

    func testMonthlyRateCompoundsBackToTheAnnualRate() {
        let monthly = Projection.monthlyRate(annual: 0.06)
        XCTAssertEqual(pow(1 + monthly, 12) - 1, 0.06, accuracy: 1e-12)
    }

    /// A twelfth root of a negative base is `NaN`, and `NaN` fails every
    /// comparison downstream — `monthsToGoal` would report "never reached" for an
    /// input that is unusable rather than merely pessimistic.
    func testMonthlyRateStaysFiniteBelowATotalLoss() {
        for annual in [-1.0, -1.5, -12.0] {
            let monthly = Projection.monthlyRate(annual: annual)
            XCTAssertFalse(monthly.isNaN, "\(annual)")
            XCTAssertEqual(monthly, -1, accuracy: 1e-12, "\(annual)")
        }
    }

    func testProjectionsStayFiniteBelowATotalLoss() {
        // Nothing compounds, so a goal above one month's deposit never arrives —
        // an answer, where a NaN rate produced the same `nil` by accident.
        XCTAssertNil(
            Projection.monthsToGoal(value: 10_000, goal: 100_000, annualRate: -2, monthlySavings: 500)
        )
        let balance = Projection.balance(
            value: 10_000, monthlyRate: Projection.monthlyRate(annual: -2),
            monthlySavings: 500, afterMonths: 12
        )
        XCTAssertEqual(balance, 500, accuracy: 1e-9)
    }

    // MARK: - Months to goal

    func testGoalAlreadyReached() {
        let months = Projection.monthsToGoal(value: 120_000, goal: 100_000, monthlyRate: 0.005, monthlySavings: 400)
        XCTAssertEqual(months, 0)
    }

    func testMonthsToGoalRoundTripsThroughTheCompoundingFormula() throws {
        let v = 12_480.50, g = 100_000.0, p = 380.0
        let r = Projection.monthlyRate(annual: Report.moderateRate)
        let t = try XCTUnwrap(Projection.monthsToGoal(value: v, goal: g, monthlyRate: r, monthlySavings: p))

        // Feed t back into the forward balance equation; it must land on the goal.
        let growth = pow(1 + r, t)
        let balance = v * growth + p * (growth - 1) / r
        XCTAssertEqual(balance, g, accuracy: 0.01)
    }

    func testMonthsToGoalAgreesWithStepwiseSimulation() throws {
        let v = 12_480.50, g = 100_000.0, p = 380.0
        let r = Projection.monthlyRate(annual: Report.moderateRate)
        let t = try XCTUnwrap(Projection.monthsToGoal(value: v, goal: g, monthlyRate: r, monthlySavings: p))

        // Simulate month by month: the goal must be crossed within one month
        // of the closed-form answer.
        var balance = v
        var months = 0
        while balance < g, months < Int(Projection.maxMonths) {
            balance = balance * (1 + r) + p
            months += 1
        }
        XCTAssertEqual(Double(months), t.rounded(.up), accuracy: 1.0)
    }

    func testZeroRateIsLinearSaving() throws {
        let months = try XCTUnwrap(
            Projection.monthsToGoal(value: 0, goal: 1_200, monthlyRate: 0, monthlySavings: 100)
        )
        XCTAssertEqual(months, 12, accuracy: 1e-9)
    }

    func testZeroRateAndNoSavingsNeverArrives() {
        XCTAssertNil(Projection.monthsToGoal(value: 5_000, goal: 100_000, monthlyRate: 0, monthlySavings: 0))
    }

    func testNoSavingsStillArrivesOnGrowthAlone() throws {
        let r = Projection.monthlyRate(annual: 0.06)
        let months = try XCTUnwrap(
            Projection.monthsToGoal(value: 50_000, goal: 100_000, monthlyRate: r, monthlySavings: 0)
        )
        // Doubling at 6% a year is the rule of 72: about twelve years.
        XCTAssertEqual(months / 12, 11.9, accuracy: 0.3)
    }

    func testNegativeRateBelowTheCeilingStillArrives() throws {
        // Losing 1%/mo while adding €1000/mo: the balance converges on
        // €100,000, so a €50,000 goal is reachable.
        let months = try XCTUnwrap(
            Projection.monthsToGoal(value: 10_000, goal: 50_000, monthlyRate: -0.01, monthlySavings: 1_000)
        )
        XCTAssertGreaterThan(months, 0)

        var balance = 10_000.0
        for _ in 0..<Int(months.rounded(.up)) {
            balance = balance * 0.99 + 1_000
        }
        XCTAssertGreaterThanOrEqual(balance, 50_000)
    }

    func testNegativeRateAboveTheCeilingNeverArrives() {
        // Same losses, but the goal sits above the €100,000 asymptote. Without
        // the ceiling guard this would take the log of a negative number.
        XCTAssertNil(
            Projection.monthsToGoal(value: 10_000, goal: 150_000, monthlyRate: -0.01, monthlySavings: 1_000)
        )
    }

    func testNegativeRateExactlyAtTheCeilingNeverArrives() {
        XCTAssertNil(
            Projection.monthsToGoal(value: 10_000, goal: 100_000, monthlyRate: -0.01, monthlySavings: 1_000)
        )
    }

    func testUnreachablyDistantGoalIsReportedAsNever() {
        XCTAssertNil(
            Projection.monthsToGoal(value: 100, goal: 10_000_000, monthlyRate: 0.0001, monthlySavings: 1)
        )
    }

    func testMoreSavingsNeverTakesLonger() throws {
        let r = Projection.monthlyRate(annual: Report.moderateRate)
        var previous = Double.infinity
        for extra in [0.0, 50, 100, 200, 500] {
            let months = try XCTUnwrap(
                Projection.monthsToGoal(value: 12_480.50, goal: 100_000, monthlyRate: r, monthlySavings: 380.0 + extra)
            )
            XCTAssertLessThan(months, previous)
            previous = months
        }
    }

    func testHigherRateNeverTakesLonger() throws {
        var previous = Double.infinity
        for annual in [0.01, 0.03, 0.06, 0.10, 0.20] {
            let months = try XCTUnwrap(
                Projection.monthsToGoal(value: 12_480.50, goal: 100_000, annualRate: annual, monthlySavings: 380.0)
            )
            XCTAssertLessThan(months, previous)
            previous = months
        }
    }


    // MARK: - Dynamization

    /// A month-by-month loop is the reference implementation: deposits are
    /// end-of-month, and the amount steps up only after twelve of them, so
    /// deposit 13 is the first raised one. The blocked closed form must agree
    /// exactly — an off-by-one here is a whole year of growth, invisible by eye.
    private func bruteForceBalance(
        value: Double,
        monthlyRate r: Double,
        monthlySavings p: Double,
        dynamizationRate g: Double,
        months: Int
    ) -> Double {
        var balance = value
        for deposit in 1...max(months, 1) where months > 0 {
            let yearsElapsed = (deposit - 1) / 12
            balance = balance * (1 + r) + p * pow(1 + g, Double(yearsElapsed))
        }
        return months > 0 ? balance : value
    }

    func testDynamizedBalanceMatchesAMonthByMonthLoopAcrossYearBoundaries() {
        let r = Projection.monthlyRate(annual: 0.06)
        // 11, 12, 13, 24, 25 straddle every boundary the blocking could slip on.
        for months in [1, 11, 12, 13, 24, 25, 47, 48, 49, 120] {
            let expected = bruteForceBalance(
                value: 12_400,
                monthlyRate: r,
                monthlySavings: 380.0,
                dynamizationRate: 0.05,
                months: months
            )
            let actual = Projection.balance(
                value: 12_400,
                monthlyRate: r,
                monthlySavings: 380.0,
                afterMonths: months,
                dynamizationRate: 0.05
            )
            XCTAssertEqual(actual, expected, accuracy: 0.01, "month \(months)")
        }
    }

    func testTheFirstTwelveDepositsAreNotYetRaised() {
        let flat = Projection.balance(
            value: 1_000, monthlyRate: 0, monthlySavings: 100, afterMonths: 12
        )
        let dynamized = Projection.balance(
            value: 1_000, monthlyRate: 0, monthlySavings: 100, afterMonths: 12, dynamizationRate: 0.05
        )
        XCTAssertEqual(flat, dynamized, accuracy: 1e-9)

        // The thirteenth deposit is the first larger one: 100 → 105.
        let thirteen = Projection.balance(
            value: 1_000, monthlyRate: 0, monthlySavings: 100, afterMonths: 13, dynamizationRate: 0.05
        )
        XCTAssertEqual(thirteen, dynamized + 105, accuracy: 1e-9)
    }

    func testDynamizationBringsTheGoalForward() throws {
        let flat = try XCTUnwrap(Projection.monthsToGoal(
            value: 12_400, goal: 50_000, annualRate: 0.06, monthlySavings: 380.0
        ))
        let dynamized = try XCTUnwrap(Projection.monthsToGoal(
            value: 12_400, goal: 50_000, annualRate: 0.06, monthlySavings: 380.0, dynamizationRate: 0.05
        ))
        XCTAssertLessThan(dynamized, flat)
    }

    /// The arrival month and the curve must land on the goal together, with the
    /// dynamized contribution as much as without — this is the cross-check that
    /// keeps the chart honest against the headline.
    func testDynamizedCurveMeetsTheGoalAtTheReportedMonth() throws {
        let r = Projection.monthlyRate(annual: 0.06)
        let months = try XCTUnwrap(Projection.monthsToGoal(
            value: 12_400, goal: 50_000, monthlyRate: r, monthlySavings: 380.0, dynamizationRate: 0.05
        ))

        let before = Projection.balance(
            value: 12_400, monthlyRate: r, monthlySavings: 380.0,
            afterMonths: Int(months.rounded(.down)), dynamizationRate: 0.05
        )
        let after = Projection.balance(
            value: 12_400, monthlyRate: r, monthlySavings: 380.0,
            afterMonths: Int(months.rounded(.up)), dynamizationRate: 0.05
        )
        XCTAssertLessThanOrEqual(before, 50_000)
        XCTAssertGreaterThanOrEqual(after, 50_000)
    }

    /// With flat contributions a losing rate caps the balance at `−P/r` and any
    /// goal above that is unreachable. A rising contribution lifts that ceiling
    /// every year, so the same goal comes into reach — walking year by year finds
    /// it, where returning nil on the first unreachable block would not.
    func testARisingContributionEscapesTheNegativeRateCeiling() throws {
        let losing = -0.10
        XCTAssertNil(Projection.monthsToGoal(
            value: 12_400, goal: 50_000, annualRate: losing, monthlySavings: 380.0
        ), "flat contributions cap out below the goal")

        let escaped = try XCTUnwrap(Projection.monthsToGoal(
            value: 12_400, goal: 50_000, annualRate: losing, monthlySavings: 380.0, dynamizationRate: 0.05
        ))
        XCTAssertGreaterThan(escaped, 12)
    }

    func testZeroDynamizationIsIdenticalToFlatContributions() throws {
        let flat = try XCTUnwrap(Projection.monthsToGoal(
            value: 12_400, goal: 50_000, annualRate: 0.06, monthlySavings: 380.0
        ))
        let zero = try XCTUnwrap(Projection.monthsToGoal(
            value: 12_400, goal: 50_000, annualRate: 0.06, monthlySavings: 380.0, dynamizationRate: 0
        ))
        XCTAssertEqual(flat, zero, accuracy: 1e-9)
    }


    // MARK: - Required contribution

    /// The solve and the forward projection must be exact inverses: contribute
    /// what it says for that many months and you land on the goal, not near it.
    ///
    /// Except where the answer is zero — past ~25 years compounding alone clears
    /// €50 000, and there the goal is overshot rather than met exactly.
    func testRequiredContributionLandsExactlyOnTheGoal() throws {
        let r = Projection.monthlyRate(annual: 0.06)
        for months in [6, 12, 13, 42, 120, 300] {
            for g in [0.0, 0.05] {
                let required = try XCTUnwrap(Projection.requiredMonthlySavings(
                    value: 12_400, goal: 50_000, monthlyRate: r, months: months, dynamizationRate: g
                ))
                let landed = Projection.balance(
                    value: 12_400, monthlyRate: r, monthlySavings: required,
                    afterMonths: months, dynamizationRate: g
                )
                if required > 0 {
                    XCTAssertEqual(landed, 50_000, accuracy: 0.01, "months \(months), g \(g)")
                } else {
                    XCTAssertGreaterThanOrEqual(landed, 50_000, "months \(months), g \(g)")
                }
            }
        }
    }

    /// A longer horizon always needs less per month.
    func testARequiredContributionFallsAsTheHorizonLengthens() throws {
        let r = Projection.monthlyRate(annual: 0.06)
        var previous = Double.infinity
        for months in [12, 24, 48, 96, 240] {
            let required = try XCTUnwrap(Projection.requiredMonthlySavings(
                value: 12_400, goal: 50_000, monthlyRate: r, months: months, dynamizationRate: 0.05
            ))
            XCTAssertLessThan(required, previous, "months \(months)")
            previous = required
        }
    }

    /// Dynamization means the answer is the *base* amount, so it is lower than a
    /// flat plan would have to be — the later years carry more of the load.
    func testDynamizationLowersTheRequiredStartingAmount() throws {
        let r = Projection.monthlyRate(annual: 0.06)
        let flat = try XCTUnwrap(Projection.requiredMonthlySavings(
            value: 12_400, goal: 50_000, monthlyRate: r, months: 120
        ))
        let dynamized = try XCTUnwrap(Projection.requiredMonthlySavings(
            value: 12_400, goal: 50_000, monthlyRate: r, months: 120, dynamizationRate: 0.05
        ))
        XCTAssertLessThan(dynamized, flat)
    }

    /// Far enough out, compounding alone clears the goal. Zero is the honest
    /// answer there, not a negative contribution.
    func testNoContributionIsNeededOnceGrowthAloneSuffices() {
        let r = Projection.monthlyRate(annual: 0.06)
        XCTAssertEqual(Projection.requiredMonthlySavings(
            value: 12_400, goal: 50_000, monthlyRate: r, months: 300
        ), 0)
    }

    func testARequiredContributionNeedsAFutureHorizon() {
        let r = Projection.monthlyRate(annual: 0.06)
        XCTAssertNil(Projection.requiredMonthlySavings(
            value: 12_400, goal: 50_000, monthlyRate: r, months: 0
        ))
    }

    /// A losing rate does not break the solve: it just needs more per month.
    func testALosingRateStillYieldsARequiredContribution() throws {
        let losing = Projection.monthlyRate(annual: -0.10)
        let required = try XCTUnwrap(Projection.requiredMonthlySavings(
            value: 12_400, goal: 50_000, monthlyRate: losing, months: 60
        ))
        let landed = Projection.balance(
            value: 12_400, monthlyRate: losing, monthlySavings: required, afterMonths: 60
        )
        XCTAssertEqual(landed, 50_000, accuracy: 0.01)
    }

    // MARK: - Dates

    func testArrivalYearCountsWholeMonthsForward() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31))!

        // 18.2 months rounds up to 19 → February 2028.
        let date = Projection.arrivalDate(months: 18.2, from: start, calendar: calendar)
        XCTAssertEqual(calendar.component(.year, from: date), 2028)
        XCTAssertEqual(calendar.component(.month, from: date), 2)
    }

    func testArrivalYearForZeroMonthsIsThisYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31))!
        XCTAssertEqual(Projection.arrivalYear(months: 0, from: start, calendar: calendar), 2026)
    }
}
