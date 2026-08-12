import Foundation

// The bounds the popover's two sliders work within: how much more could be
// saved, and which target years are worth offering.

extension Report {

    // MARK: - Slider bounds

    /// Upper bound for the "save more" slider, as an *extra* monthly amount.
    ///
    /// Whichever is larger of: twice the current contribution, or enough extra to
    /// **halve the time to the goal**.
    ///
    /// The doubling alone scales with saving habit but not with ambition — it was
    /// a sensible span for a €50 000 goal and stopped well short of the
    /// interesting part of a €1 000 000 one, where the whole slider still left a
    /// decade to run. Halving the horizon is the ambition the goal itself implies,
    /// and it also keeps the two sliders on the same ground: "reach by" can quote
    /// a figure this one can now actually reach.
    ///
    /// Halving is used rather than the earliest offered target year on purpose —
    /// reaching €1 000 000 by next year needs about €55 000 a month, and a slider
    /// running that far is worse than one stopping too soon.
    public var extraSavingsCeiling: Double {
        let doubled = max(snapshot.monthlySavings, 100) * 2

        guard let months = headlineMonths, months >= 2 else { return Self.tidyBound(doubled) }
        let halved = max(Int((months / 2).rounded()), 1)
        let required = Projection.requiredMonthlySavings(
            value: snapshot.total,
            goal: goal,
            annualRate: headlineRate,
            months: halved,
            dynamizationRate: snapshot.dynamizationRate
        ) ?? 0

        let extra = max(required - snapshot.monthlySavings, 0)
        return Self.tidyBound(max(doubled, extra))
    }

    /// Rounds a slider bound up to a round number, coarser as it grows, so the
    /// end label reads as a bound someone chose rather than as arithmetic.
    private static func tidyBound(_ amount: Double) -> Double {
        let increment: Double = amount < 1_000 ? 50 : 250
        return (amount / increment).rounded(.up) * increment
    }

    // MARK: - Target year

    /// Years the "reach by" slider offers: next year through twenty years out.
    ///
    /// It starts next year rather than this one because a horizon of a few
    /// remaining months demands an absurd contribution, and it deliberately
    /// extends past the projected arrival — dragging *later* answers "how much
    /// could I ease off and still make it?", which is as useful as the other
    /// direction.
    public var targetYearRange: ClosedRange<Int> {
        let thisYear = calendar.component(.year, from: asOf)
        return (thisYear + 1)...(thisYear + 20)
    }

    /// Months from now to the end of `year` — the horizon behind
    /// `requiredMonthlySavings(byYear:)`.
    ///
    /// Measured to December because "reach it by 2031" means any time in 2031,
    /// so the horizon is the whole year. Anchoring on January instead would
    /// quote a contribution nearly a year's worth too aggressive.
    public func monthsUntilEndOf(year: Int) -> Int? {
        let components = DateComponents(year: year, month: 12, day: 31)
        guard let end = calendar.date(from: components) else { return nil }
        let months = calendar.dateComponents([.month], from: asOf, to: end).month ?? 0
        return months > 0 ? months : nil
    }

    /// A few target years worth quoting in the text output: side-stepping the
    /// projected arrival so `--once` shows both directions of the trade.
    public var targetYearSamples: [Int] {
        let range = targetYearRange
        let anchor = headlineYear ?? range.lowerBound + 2
        return [anchor - 2, anchor, anchor + 2]
            .map { min(max($0, range.lowerBound), range.upperBound) }
            .reduce(into: []) { unique, year in
                if !unique.contains(year) { unique.append(year) }
            }
    }

    /// `(year, required, delta against what is saved now)` per sampled year.
    public var requiredSavingsRows: [(year: Int, required: Double?, delta: Double?)] {
        targetYearSamples.map { year in
            let required = requiredMonthlySavings(byYear: year)
            return (year, required, required.map { $0 - snapshot.monthlySavings })
        }
    }

    /// The monthly contribution needed to reach the goal by the end of `year`, at
    /// the headline rate.
    ///
    /// With dynamization this is the amount to *start* at — it steps up annually
    /// from there, exactly like the plan it would replace. `0` means growth alone
    /// gets there; `nil` means the year is not in the future.
    public func requiredMonthlySavings(byYear year: Int) -> Double? {
        guard let months = monthsUntilEndOf(year: year) else { return nil }
        return Projection.requiredMonthlySavings(
            value: snapshot.total,
            goal: goal,
            annualRate: headlineRate,
            months: months,
            dynamizationRate: snapshot.dynamizationRate
        )
    }
}
