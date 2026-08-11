import Foundation

/// Everything the holdings page shows, derived once from the two calls it makes
/// and the projection already on screen.
///
/// The same shape as `Report` and for the same reason: the view reads finished
/// values and holds no arithmetic, so the whole page can be asserted on without a
/// window. Note what it takes from `Report` rather than recomputing — the goal and
/// the rate — so the weeks on this page are measured against the very year the
/// popover behind it is claiming.
public struct HoldingsReport: Equatable {

    public let holdings: HoldingsSnapshot
    public let contributions: TimeContributions

    /// The projection these weeks were measured against.
    ///
    /// Kept though nothing prints it: it is the record of *which* projection the page
    /// was computed from, and `AppModel` compares the goal against the live one to
    /// know when a cached page has gone stale.
    public let annualRate: Double
    public let goal: Double

    /// When the projection was struck, and in which calendar — both needed to turn
    /// months into the two years the page leads with.
    private let asOf: Date
    private let calendar: Calendar

    public init(holdings: HoldingsSnapshot, report: Report) {
        self.holdings = holdings
        self.annualRate = report.headlineRate
        self.goal = report.goal
        self.asOf = report.asOf
        self.calendar = report.calendar
        self.contributions = TimeContributions.make(
            holdings: holdings,
            goal: report.goal,
            annualRate: report.headlineRate,
            monthlySavings: report.snapshot.monthlySavings,
            dynamizationRate: report.snapshot.dynamizationRate
        )
    }

    /// Whether there is any position to draw. Everything else on the page is
    /// optional; without this there is no page.
    public var isEmpty: Bool { holdings.items.isEmpty }

    /// The year the goal arrives, as things stand.
    ///
    /// Derived here rather than read from `Report.headlineYear` so it and the
    /// counterfactual below come out of the same arithmetic — a pair of years where
    /// one was computed two different ways could show a difference of a year that is
    /// really a difference of rounding.
    public var arrivalYear: Int? {
        contributions.baseMonths.map {
            Projection.arrivalYear(months: $0, from: asOf, calendar: calendar)
        }
    }

    /// The year the goal would arrive if the portfolio had made nothing — the same
    /// contributions, none of the growth.
    ///
    /// `nil` when the goal is never reached without the gains. That is a real answer
    /// and a stronger one than a year, so the page says it in words rather than
    /// printing a date a century out.
    public var arrivalYearWithoutGains: Int? {
        contributions.monthsWithoutGains.map {
            Projection.arrivalYear(months: $0, from: asOf, calendar: calendar)
        }
    }

    /// Whether the two years differ enough to be worth showing as a pair. Identical
    /// years would present a gain of a few weeks as though nothing had happened.
    public var yearsDiffer: Bool {
        guard let arrivalYear, let arrivalYearWithoutGains else { return false }
        return arrivalYear != arrivalYearWithoutGains
    }

    /// The position whose return is furthest from the portfolio's own, when it is
    /// far enough out to be worth pointing at.
    ///
    /// Ten points is a judgement, not a finding: below it a spread of returns is
    /// just what a portfolio of different funds looks like, and highlighting one
    /// would invent a story out of ordinary variation.
    public var outlier: Holding? {
        guard let portfolio = holdings.sinceBuyReturn else { return nil }
        let candidate = holdings.items
            .compactMap { holding -> (Holding, Double)? in
                guard let own = holding.sinceBuyReturn else { return nil }
                return (holding, abs(own - portfolio))
            }
            .max { $0.1 < $1.1 }
        guard let candidate, candidate.1 >= Self.outlierThreshold else { return nil }
        return candidate.0
    }

    /// Distance from the portfolio's own return, as a fraction, at which a position
    /// is worth marking.
    static let outlierThreshold = 0.10
}
