import Foundation

/// One projection scenario: a growth assumption and what it implies.
public struct Scenario: Equatable {
    public let label: String
    /// `nil` for the realized scenario when there is not enough history.
    public let annualRate: Double?
    /// Months until the goal; `nil` means it is never reached.
    public let months: Double?
    public let year: Int?

    public var isReachable: Bool { months != nil }
}

/// The effect of adding a fixed amount to the monthly contribution.
public struct WhatIf: Equatable {
    public let extraPerMonth: Double
    public let year: Int?
    /// Years shaved off the headline projection.
    public let yearsSaved: Double?
}

/// The complete view model: everything the UI shows, derived once from a
/// snapshot and a goal.
///
/// Deliberately free of AppKit so the entire display can be rendered as text
/// and asserted on in tests.
public struct Report {

    /// A deliberately conservative growth assumption.
    public static let cautiousRate = 0.03

    /// A long-run equity return, and the headline's fallback when the portfolio
    /// has no measurable pace of its own yet.
    public static let moderateRate = 0.06

    /// Scenario labels. Named rather than spelled out at each use site so the
    /// headline, the highlighted row and the emphasised curve cannot drift apart —
    /// which is also what lets them be translated: everything that keys off a
    /// scenario compares against these, never against a literal.
    public static var cautiousLabel: String { Strings.cautious }
    public static var moderateLabel: String { Strings.moderate }
    public static var realizedLabel: String { Strings.yourPace }

    /// Extra monthly contributions offered as what-if rows.
    public static let whatIfIncrements: [Double] = [50, 100, 200]

    public let goal: Double
    public let snapshot: PortfolioSnapshot
    public let asOf: Date
    /// Retained so every date derived later — including the slider's continuous
    /// what-if — uses the same calendar the fixed scenarios did.
    public let calendar: Calendar

    /// Fraction of the goal already reached, capped at 1.
    public let progress: Double

    /// Trailing return implied by the past year, or `nil` if not derivable.
    public let realizedAnnualRate: Double?

    /// The rate the headline, the what-ifs and the slider all project with: the
    /// realized pace when there is one, otherwise the moderate assumption.
    public let headlineRate: Double

    /// Which scenario the headline came from, so the UI can highlight that row
    /// and emphasise that curve without hardcoding a label.
    public let headlineLabel: String

    public let headlineMonths: Double?
    public let headlineYear: Int?
    public let scenarios: [Scenario]
    public let whatIfs: [WhatIf]

    public var isGoalReached: Bool { snapshot.total >= goal }
    public var remaining: Double { max(goal - snapshot.total, 0) }

    public init(goal: Double, snapshot: PortfolioSnapshot, now: Date = Date(), calendar: Calendar = .current) {
        self.goal = goal
        self.snapshot = snapshot
        self.asOf = now
        self.calendar = calendar
        self.progress = goal > 0 ? min(snapshot.total / goal, 1) : 0

        let realized = Projection.realizedAnnualRate(
            total: snapshot.total,
            oneYearGain: snapshot.oneYearGain,
            monthlySavings: snapshot.monthlySavings,
            trailingContributions: snapshot.trailingContributions
        )
        self.realizedAnnualRate = realized

        // The headline follows the portfolio's own measured pace — the whole
        // point of the widget is that the year adapts to how the portfolio is
        // actually doing. The fallback turns on whether a rate could be measured
        // at all, never on whether the answer is flattering: a pace too poor to
        // reach the goal yields no year rather than borrowing the moderate one.
        let headlineRate = realized ?? Self.moderateRate
        self.headlineRate = headlineRate
        self.headlineLabel = realized == nil ? Self.moderateLabel : Self.realizedLabel

        let headline = Projection.monthsToGoal(
            value: snapshot.total,
            goal: goal,
            annualRate: headlineRate,
            monthlySavings: snapshot.monthlySavings,
            dynamizationRate: snapshot.dynamizationRate
        )
        self.headlineMonths = headline
        self.headlineYear = headline.map { Projection.arrivalYear(months: $0, from: now, calendar: calendar) }

        self.scenarios = [
            (Self.cautiousLabel, Self.cautiousRate),
            (Self.moderateLabel, Self.moderateRate),
            (Self.realizedLabel, realized),
        ].map { label, rate in
            Self.makeScenario(
                label: label,
                annualRate: rate,
                goal: goal,
                snapshot: snapshot,
                now: now,
                calendar: calendar
            )
        }

        self.whatIfs = Self.whatIfIncrements.map { extra in
            Self.makeWhatIf(
                extra: extra,
                goal: goal,
                snapshot: snapshot,
                annualRate: headlineRate,
                headlineMonths: headline,
                now: now,
                calendar: calendar
            )
        }
    }

    // MARK: - Derivation

    private static func makeScenario(
        label: String,
        annualRate: Double?,
        goal: Double,
        snapshot: PortfolioSnapshot,
        now: Date,
        calendar: Calendar
    ) -> Scenario {
        guard let annualRate else {
            return Scenario(label: label, annualRate: nil, months: nil, year: nil)
        }
        let months = Projection.monthsToGoal(
            value: snapshot.total,
            goal: goal,
            annualRate: annualRate,
            monthlySavings: snapshot.monthlySavings,
            dynamizationRate: snapshot.dynamizationRate
        )
        return Scenario(
            label: label,
            annualRate: annualRate,
            months: months,
            year: months.map { Projection.arrivalYear(months: $0, from: now, calendar: calendar) }
        )
    }

    private static func makeWhatIf(
        extra: Double,
        goal: Double,
        snapshot: PortfolioSnapshot,
        annualRate: Double,
        headlineMonths: Double?,
        now: Date,
        calendar: Calendar
    ) -> WhatIf {
        // Must be the headline's own rate: comparing a what-if projected at one
        // rate against a headline projected at another would report time saved
        // that is really just the difference between the two assumptions.
        let months = Projection.monthsToGoal(
            value: snapshot.total,
            goal: goal,
            annualRate: annualRate,
            monthlySavings: snapshot.monthlySavings + extra,
            dynamizationRate: snapshot.dynamizationRate
        )
        var saved: Double?
        if let months, let headlineMonths {
            saved = (headlineMonths - months) / 12
        }
        return WhatIf(
            extraPerMonth: extra,
            year: months.map { Projection.arrivalYear(months: $0, from: now, calendar: calendar) },
            yearsSaved: saved
        )
    }
}
