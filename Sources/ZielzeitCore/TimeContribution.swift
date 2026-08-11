import Foundation

/// What one holding's gain is worth in arrival date rather than in money.
///
/// The app's whole premise is that a portfolio is a date, not a balance. This is
/// the same conversion applied one position at a time: take the projection as it
/// stands, remove a holding's unrealised gain from the total, and see how much
/// later the goal arrives without it.
public struct TimeContribution: Equatable, Identifiable {

    public let holding: Holding

    /// Weeks the goal arrives *earlier* thanks to this holding's gain. Negative
    /// for a position that is down, since removing a loss brings the date forward.
    ///
    /// `nil` when the goal is not reached without this holding at all, which is
    /// not a number of weeks but a different statement — and the page says so in
    /// words rather than drawing a bar of unbounded length.
    public let weeks: Double?

    public var id: String { holding.isin }

    public init(holding: Holding, weeks: Double?) {
        self.holding = holding
        self.weeks = weeks
    }
}

/// The per-holding time contributions for a portfolio, and their total.
public struct TimeContributions: Equatable {

    public let items: [TimeContribution]

    /// Weeks the goal arrives earlier thanks to every gain together.
    ///
    /// Computed in one go rather than by summing `items`, and the two will differ
    /// slightly: compounding is not additive, so removing five gains at once is
    /// not the same as removing each in turn. This is the honest headline — what
    /// the portfolio's total gain is actually worth — and the bars beneath it are
    /// each position's share of the credit, which is why they do not add up to it.
    public let totalWeeks: Double?

    /// Months to the goal as things stand, and as they would stand with no gains at
    /// all.
    ///
    /// Kept as months rather than converted here so the page can state the pair as
    /// two *years* — the unit the rest of the app has taught its reader — instead of
    /// only as the difference between them. "8.8 weeks earlier" is a quantity;
    /// "2038 rather than 2040" is the same fact in the language of the app.
    public let baseMonths: Double?
    public let monthsWithoutGains: Double?

    public init(
        items: [TimeContribution],
        totalWeeks: Double?,
        baseMonths: Double? = nil,
        monthsWithoutGains: Double? = nil
    ) {
        self.items = items
        self.totalWeeks = totalWeeks
        self.baseMonths = baseMonths
        self.monthsWithoutGains = monthsWithoutGains
    }

    public var isEmpty: Bool { items.isEmpty }

    /// Largest contribution first. Positions whose contribution could not be put
    /// in weeks sort last, since they have no magnitude to rank by.
    public var ranked: [TimeContribution] {
        items.sorted { left, right in
            switch (left.weeks, right.weeks) {
            case let (l?, r?): return l > r
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return left.holding.valuation > right.holding.valuation
            }
        }
    }

    /// The largest single contribution, which the bars are scaled against.
    public var peakWeeks: Double? {
        items.compactMap(\.weeks).map(abs).max()
    }

    /// Whether any position took time away rather than gave it.
    ///
    /// Decides whether the bars need an axis down the middle at all. With every
    /// contribution positive — the ordinary case for a portfolio that is up — a
    /// centred axis would leave half of every track permanently empty and read as
    /// an indent rather than as a sign.
    public var hasNegative: Bool {
        items.contains { ($0.weeks ?? 0) < 0 }
    }
}

extension TimeContributions {

    /// Weeks in a month, on the same 52-week year the rest of the app's
    /// month-to-week wording assumes.
    static let weeksPerMonth = 52.0 / 12.0

    /// Works out what each holding's gain bought, in weeks.
    ///
    /// `value` deliberately comes from the holdings themselves rather than from
    /// `PortfolioSnapshot.total`: the counterfactual has to be subtracted from the
    /// same figure the base projection used, or the difference picks up the few
    /// euros by which two separate calls disagree instead of the gain being tested.
    ///
    /// Returns nothing at all when the goal is already met or is not reached on
    /// these assumptions — with no arrival date there is nothing to move.
    public static func make(
        holdings: HoldingsSnapshot,
        goal: Double,
        annualRate: Double,
        monthlySavings: Double,
        dynamizationRate: Double = 0
    ) -> TimeContributions {
        let total = holdings.total
        guard goal > total else { return TimeContributions(items: [], totalWeeks: nil) }

        guard let base = Projection.monthsToGoal(
            value: total,
            goal: goal,
            annualRate: annualRate,
            monthlySavings: monthlySavings,
            dynamizationRate: dynamizationRate
        ) else {
            return TimeContributions(items: [], totalWeeks: nil)
        }

        /// Months until the goal with `removed` euros taken off today's total.
        func monthsWithout(_ removed: Double) -> Double? {
            Projection.monthsToGoal(
                value: total - removed,
                goal: goal,
                annualRate: annualRate,
                monthlySavings: monthlySavings,
                dynamizationRate: dynamizationRate
            )
        }

        func weeksEarlier(withoutGain removed: Double) -> Double? {
            monthsWithout(removed).map { ($0 - base) * weeksPerMonth }
        }

        let items = holdings.items.map { holding in
            TimeContribution(
                holding: holding,
                weeks: weeksEarlier(withoutGain: holding.unrealisedGain)
            )
        }

        return TimeContributions(
            items: items,
            totalWeeks: weeksEarlier(withoutGain: holdings.unrealisedGain),
            baseMonths: base,
            monthsWithoutGains: monthsWithout(holdings.unrealisedGain)
        )
    }
}
