import Foundation

// What the projection looks like as a curve, and when each scenario arrives.

extension Report {

    /// A scenario's balance curve, ready to plot.
    public struct Curve: Identifiable {
        public let label: String
        public let annualRate: Double
        /// Monthly samples, ending on the goal line if the goal is reached.
        public let points: [Projection.BalancePoint]
        /// Months to the goal, `nil` if never reached within the horizon.
        public let arrivalMonths: Double?

        public var id: String { label }
        public var reachesGoal: Bool { arrivalMonths != nil }
    }

    /// How far the chart's x-axis runs, in months.
    ///
    /// Chosen so the slowest scenario that does arrive fits with a little room
    /// to spare; falls back to 40 years when nothing arrives at all.
    public func chartHorizonMonths(extraMonthlySavings: Double = 0) -> Int {
        let arrivals = scenarioRates.compactMap { rate in
            Projection.monthsToGoal(
                value: snapshot.total,
                goal: goal,
                annualRate: rate,
                monthlySavings: snapshot.monthlySavings + extraMonthlySavings,
                dynamizationRate: snapshot.dynamizationRate
            )
        }
        guard let slowest = arrivals.max() else { return 480 }
        return max(Int((slowest * 1.08).rounded(.up)), 12)
    }

    /// Balance curves for every scenario, each stopping at the goal line.
    ///
    /// Recomputing this is cheap arithmetic, so the what-if slider can call it
    /// on every drag.
    public func curves(extraMonthlySavings: Double = 0) -> [Curve] {
        let horizon = chartHorizonMonths(extraMonthlySavings: extraMonthlySavings)
        // Thin the samples on long horizons; ~120 points is plenty for a
        // smooth line at this width.
        let step = max(horizon / 120, 1)
        let savings = snapshot.monthlySavings + extraMonthlySavings

        return scenarios.compactMap { scenario -> Curve? in
            guard let annualRate = scenario.annualRate else { return nil }
            let monthlyRate = Projection.monthlyRate(annual: annualRate)
            let arrival = Projection.monthsToGoal(
                value: snapshot.total,
                goal: goal,
                monthlyRate: monthlyRate,
                monthlySavings: savings,
                dynamizationRate: snapshot.dynamizationRate
            )
            return Curve(
                label: scenario.label,
                annualRate: annualRate,
                points: Projection.balanceSeries(
                    value: snapshot.total,
                    monthlyRate: monthlyRate,
                    monthlySavings: savings,
                    months: horizon,
                    step: step,
                    ceiling: goal,
                    dynamizationRate: snapshot.dynamizationRate
                ),
                arrivalMonths: arrival
            )
        }
    }

    /// The rates actually plotted: the two fixed scenarios plus the realized one
    /// when it is derivable.
    private var scenarioRates: [Double] {
        scenarios.compactMap(\.annualRate)
    }

    /// Arrival for an arbitrary extra monthly contribution at the headline's own
    /// rate, so the previewed year is comparable with the one it replaces.
    public func arrival(
        extraMonthlySavings: Double
    ) -> (months: Double?, year: Int?, yearsSaved: Double?) {
        arrival(extraMonthlySavings: extraMonthlySavings, annualRate: headlineRate)
    }

    /// The same preview at an explicit rate, for `ScenarioListView`'s per-row
    /// years. Deliberately non-optional: a `nil` rate means "no year at all",
    /// and silently substituting the headline's rate would print a year on the
    /// row that is supposed to read `—`.
    ///
    /// The extra dynamizes along with the plan. Raising what you save here means
    /// raising the Scalable savings plan, and that raised amount carries the same
    /// annual step-up — treating the extra as a flat standing transfer instead
    /// would report slightly smaller savings.
    public func arrival(
        extraMonthlySavings: Double,
        annualRate: Double
    ) -> (months: Double?, year: Int?, yearsSaved: Double?) {
        let months = Projection.monthsToGoal(
            value: snapshot.total,
            goal: goal,
            annualRate: annualRate,
            monthlySavings: snapshot.monthlySavings + extraMonthlySavings,
            dynamizationRate: snapshot.dynamizationRate
        )
        var saved: Double?
        if let months, let headlineMonths {
            saved = (headlineMonths - months) / 12
        }
        return (
            months,
            months.map { Projection.arrivalYear(months: $0, from: asOf, calendar: calendar) },
            saved
        )
    }
}
