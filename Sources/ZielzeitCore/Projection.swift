import Foundation

/// Projection math: how long until a portfolio compounds up to a goal amount.
///
/// All of this is pure arithmetic on `Double`s so it can be tested without
/// touching the network or AppKit.
public enum Projection {

    /// Trailing returns beyond this magnitude are treated as noise from an
    /// unusual year rather than a rate worth extrapolating for decades.
    public static let rateClamp = 0.30

    /// Past this horizon we report "never" instead of a year in the 2100s.
    public static let maxMonths = 1200.0

    // MARK: - Rate estimation

    /// Trailing annual return estimated with the simple Dietz method, which
    /// approximates the average invested capital by assuming contributions
    /// arrive evenly across the year.
    ///
    /// Returns `nil` when the estimate would be meaningless: no one-year
    /// figure available, or a capital base of zero or less. The latter is not
    /// hypothetical — a portfolio younger than a year, or one where deposits
    /// dominate growth, drives the denominator negative.
    /// `trailingContributions` is the *measured* net external flow of the past
    /// year — deposits less withdrawals, read from `sc broker transactions`. When
    /// it is `nil` the contribution is estimated as `12 × monthlySavings`, which
    /// is only right for someone whose plan ran unchanged all year and paid in
    /// nothing besides.
    ///
    /// The estimate is not a small approximation, and it errs in *both*
    /// directions, because a larger contribution means a smaller Dietz denominator
    /// and so a higher rate:
    ///
    /// - A plan that stepped up during the year makes `12 × monthly` **too large**,
    ///   which **overstates** the pace. On the portfolio this was built against the
    ///   estimate said 22.9% where the measured flow says 21.8%.
    /// - Manual buying out of the same account makes it **too small**, which
    ///   **understates** the pace — the extra capital looks like it was there all
    ///   along earning the gain.
    ///
    /// Which is why this is worth measuring rather than correcting for: there is no
    /// safe direction to lean.
    public static func realizedAnnualRate(
        total: Double,
        oneYearGain: Double?,
        monthlySavings: Double,
        trailingContributions: Double? = nil
    ) -> Double? {
        guard let gain = oneYearGain else { return nil }
        let contributions = trailingContributions ?? 12 * monthlySavings
        let base = total - gain - contributions / 2
        guard base > 0 else { return nil }
        return min(max(gain / base, -rateClamp), rateClamp)
    }

    /// Geometric annual-to-monthly conversion. Used for every scenario so the
    /// comparison between them is apples-to-apples.
    ///
    /// Floored at −100% a year, which is the edge of the conversion's domain: a
    /// twelfth root of a negative base is `NaN`, and `NaN` does not announce
    /// itself here — every comparison against it is false, so `monthsToGoal`
    /// would quietly answer "never reached" for what is really an unusable input.
    /// The floor keeps the arithmetic finite and the failure legible instead. It
    /// cannot be reached from inside the app, where `rateClamp` holds every rate
    /// to ±30%; it is the public entry point that needs the guard.
    public static func monthlyRate(annual: Double) -> Double {
        pow(1 + max(annual, -1), 1.0 / 12.0) - 1
    }

    // MARK: - Dynamization

    /// Scalable's savings plans carry a *dynamization rate*: the contribution is
    /// raised by that percentage **once a year**, as an inflation adjustment.
    /// (`dynamization_rate: 5` in the CLI payload means 5% p.a., not per month.)
    ///
    /// The payload says nothing about *when* the raise fires — there is a
    /// `next_execution_date` for the deposit but no dynamization anniversary — so
    /// every function here puts the first raise a full twelve deposits out. That
    /// is the most conservative reading: the latest possible raise, hence the
    /// latest possible arrival. It is an assumption, not something the API told
    /// us.
    ///
    /// Deposits are end-of-month (an ordinary annuity, matching the closed form
    /// below), so deposits 1…12 are made at the base amount and deposit 13 is
    /// the first raised one.
    static func contributionsGrow(at rate: Double) -> Bool {
        abs(rate) > 1e-12
    }

    // MARK: - Time to goal

    /// Months of monthly compounding until `value` grows to `goal`.
    ///
    /// With `dynamizationRate` at its default of zero this solves
    /// `V·(1+r)^t + P·((1+r)^t − 1)/r = G` for `t` directly, which rearranges to
    /// `t = ln((G·r + P) / (V·r + P)) / ln(1 + r)`.
    ///
    /// A non-zero `dynamizationRate` makes the contribution a step function of
    /// time, which that formula cannot express. Rather than solve numerically,
    /// each twelve-month block is handled by the same closed form at that year's
    /// contribution, walking forward a year at a time until the goal falls inside
    /// a block. The result is exact and shares its boundary convention with
    /// `balance(afterMonths:)`, so the chart and the headline cannot disagree.
    ///
    /// Returns `0` if the goal is already met, and `nil` if it is never
    /// reached — either because nothing is growing or being added, or because
    /// a negative rate caps the balance below the goal.
    public static func monthsToGoal(
        value: Double,
        goal: Double,
        monthlyRate r: Double,
        monthlySavings p: Double,
        dynamizationRate g: Double = 0
    ) -> Double? {
        guard contributionsGrow(at: g) else {
            return flatMonthsToGoal(value: value, goal: goal, monthlyRate: r, monthlySavings: p)
        }
        if value >= goal { return 0 }

        var balance = value
        var contribution = p
        var elapsed = 0.0

        while elapsed < maxMonths {
            // Within a year the contribution is constant, so the closed form
            // applies exactly; a result beyond twelve months just means the goal
            // is not reached in this year's block.
            if let months = flatMonthsToGoal(
                value: balance,
                goal: goal,
                monthlyRate: r,
                monthlySavings: contribution
            ), months <= 12 {
                let total = elapsed + months
                return total <= maxMonths ? total : nil
            }

            // A losing rate with flat contributions converges on a ceiling of
            // `−P/r`, and the block above returns nil for any goal above it. That
            // is not the end of the story here: next year's contribution is
            // larger, so the ceiling rises with it and a goal out of reach today
            // can come into reach later. Walking forward finds that; returning
            // nil on the first unreachable block would not.
            balance = flatBalance(value: balance, monthlyRate: r, monthlySavings: contribution, afterMonths: 12)
            elapsed += 12
            contribution *= (1 + g)
        }
        return nil
    }

    private static func flatMonthsToGoal(
        value: Double,
        goal: Double,
        monthlyRate r: Double,
        monthlySavings p: Double
    ) -> Double? {
        if value >= goal { return 0 }

        // Flat rate: linear savings, or no progress at all.
        if abs(r) < 1e-12 {
            guard p > 0 else { return nil }
            let months = (goal - value) / p
            return months > maxMonths ? nil : months
        }

        // A negative rate means the balance converges on a ceiling where
        // monthly losses exactly cancel the monthly contribution. Above that
        // ceiling the goal is unreachable and the logarithm below would be
        // taken of a negative number.
        if r < 0 {
            let ceiling = -p / r
            if goal >= ceiling { return nil }
        }

        let numerator = goal * r + p
        let denominator = value * r + p
        guard numerator > 0, denominator > 0 else { return nil }

        let months = log(numerator / denominator) / log(1 + r)
        guard months >= 0, months <= maxMonths else { return nil }
        return months
    }

    /// Convenience wrapper taking an annual rate.
    public static func monthsToGoal(
        value: Double,
        goal: Double,
        annualRate: Double,
        monthlySavings: Double,
        dynamizationRate: Double = 0
    ) -> Double? {
        monthsToGoal(
            value: value,
            goal: goal,
            monthlyRate: monthlyRate(annual: annualRate),
            monthlySavings: monthlySavings,
            dynamizationRate: dynamizationRate
        )
    }

    // MARK: - Purchasing power

    /// The euro area's inflation target, used as the default assumption.
    ///
    /// An assumption and nothing more — but the alternative is the implicit
    /// assumption of zero, which is the one figure certain to be wrong.
    public static let assumedInflation = 0.02

    /// What `nominal` euros `months` from now are worth in today's money.
    ///
    /// `V / (1 + i)^(t/12)`, the same geometric annual-to-monthly treatment every
    /// rate in here gets. Discounting the *goal* rather than inflating the
    /// contribution on purpose: the goal is the number the user chose and the one
    /// they picture, so restating it is what makes the erosion legible — "€100 000
    /// then is €92 000 now" lands where "you'll need €108 000" does not.
    public static func realValue(
        nominal: Double,
        months: Double,
        annualInflation: Double = assumedInflation
    ) -> Double {
        guard months > 0, annualInflation > -1 else { return nominal }
        return nominal / pow(1 + annualInflation, months / 12)
    }

    // MARK: - Required contribution

    /// The monthly contribution needed to reach `goal` in exactly `months`.
    ///
    /// The inverse of `balance(afterMonths:)`, and solvable in closed form even
    /// with dynamization: the balance is `V·(1+r)^t + P·A`, where `A` depends on
    /// the rate and the step-up but *not* on `P`. So `A` is read off by running
    /// the same walk with no starting capital and a contribution of 1, and `P`
    /// falls out by division. No search, no tolerance, and it cannot disagree
    /// with `balance` because it calls it.
    ///
    /// With dynamization the answer is the **base** contribution: it is what you
    /// start at, and it steps up annually from there like any other plan.
    ///
    /// Returns `0` when the portfolio reaches the goal on growth alone — "you
    /// need to add nothing" is a real answer, not a failure — and `nil` when the
    /// question is unanswerable (a horizon of zero months or less).
    public static func requiredMonthlySavings(
        value: Double,
        goal: Double,
        monthlyRate r: Double,
        months: Int,
        dynamizationRate g: Double = 0
    ) -> Double? {
        guard months > 0 else { return nil }

        let grown = value * pow(1 + r, Double(months))
        let shortfall = goal - grown
        guard shortfall > 0 else { return 0 }

        // The contribution factor: what a €1 monthly plan accumulates over the
        // same horizon, dynamized identically.
        let unit = balance(
            value: 0,
            monthlyRate: r,
            monthlySavings: 1,
            afterMonths: months,
            dynamizationRate: g
        )
        guard unit > 0 else { return nil }
        return shortfall / unit
    }

    /// Convenience wrapper taking an annual rate.
    public static func requiredMonthlySavings(
        value: Double,
        goal: Double,
        annualRate: Double,
        months: Int,
        dynamizationRate: Double = 0
    ) -> Double? {
        requiredMonthlySavings(
            value: value,
            goal: goal,
            monthlyRate: monthlyRate(annual: annualRate),
            months: months,
            dynamizationRate: dynamizationRate
        )
    }

    // MARK: - Balance over time

    /// One point on a projected balance curve.
    ///
    /// `month` is fractional rather than whole because of the last point: samples
    /// land on whole months, but a curve stopped at a ceiling stops where it
    /// actually crosses, which is somewhere inside a month.
    public struct BalancePoint: Equatable, Identifiable {
        public let month: Double
        public let balance: Double
        public var id: Double { month }
    }

    /// The balance after `month` months of compounding plus contributions.
    ///
    /// The closed form of the same recurrence `monthsToGoal` inverts, so the two
    /// cannot drift apart — including the twelve-month blocking a non-zero
    /// `dynamizationRate` introduces, which both walk identically.
    public static func balance(
        value: Double,
        monthlyRate r: Double,
        monthlySavings p: Double,
        afterMonths month: Int,
        dynamizationRate g: Double = 0
    ) -> Double {
        guard month > 0 else { return value }
        guard contributionsGrow(at: g) else {
            return flatBalance(value: value, monthlyRate: r, monthlySavings: p, afterMonths: month)
        }

        var balance = value
        var contribution = p
        var remaining = month

        while remaining > 0 {
            let block = min(remaining, 12)
            balance = flatBalance(
                value: balance,
                monthlyRate: r,
                monthlySavings: contribution,
                afterMonths: block
            )
            remaining -= block
            // Only after a full twelve deposits does the next one step up, so
            // deposit 13 is the first raised one.
            if remaining > 0 { contribution *= (1 + g) }
        }
        return balance
    }

    private static func flatBalance(
        value: Double,
        monthlyRate r: Double,
        monthlySavings p: Double,
        afterMonths month: Int
    ) -> Double {
        guard month > 0 else { return value }
        if abs(r) < 1e-12 { return value + p * Double(month) }
        let growth = pow(1 + r, Double(month))
        return value * growth + p * (growth - 1) / r
    }

    /// A balance curve sampled monthly, optionally stopped once it reaches
    /// `ceiling` (used to end each curve exactly at the goal line rather than
    /// letting a fast scenario run off the top of the chart).
    ///
    /// `step` thins the samples for long horizons; the final point is always
    /// included so a curve never appears to stop short.
    public static func balanceSeries(
        value: Double,
        monthlyRate r: Double,
        monthlySavings p: Double,
        months: Int,
        step: Int = 1,
        ceiling: Double? = nil,
        dynamizationRate g: Double = 0
    ) -> [BalancePoint] {
        guard months > 0 else { return [BalancePoint(month: 0, balance: value)] }
        let stride = max(step, 1)

        // Where the curve meets the ceiling, solved rather than sampled. `step`
        // thins the samples on a long horizon, so the first sample at or above the
        // ceiling can be several months past the crossing — and that sample is the
        // point a chart draws its arrival dot on, beside a year taken from the
        // exact figure. Same function and same arguments the headline's arrival
        // comes from, so the two are one number rather than two that agree.
        let crossing = ceiling.flatMap {
            monthsToGoal(value: value, goal: $0, monthlyRate: r, monthlySavings: p, dynamizationRate: g)
        }

        var points: [BalancePoint] = []
        var month = 0
        while month <= months {
            let balance = self.balance(
                value: value,
                monthlyRate: r,
                monthlySavings: p,
                afterMonths: month,
                dynamizationRate: g
            )
            if let ceiling, balance >= ceiling {
                // Land the curve on the ceiling instead of overshooting past it —
                // at the crossing when it could be solved, and at this sample when
                // it could not, which is the horizon running past `maxMonths`.
                points.append(BalancePoint(month: crossing ?? Double(month), balance: ceiling))
                return points
            }
            points.append(BalancePoint(month: Double(month), balance: balance))
            if month == months { break }
            month = min(month + stride, months)
        }
        return points
    }

    // MARK: - Dates

    /// The calendar date `months` from `from`, rounding partial months up.
    public static func arrivalDate(
        months: Double,
        from: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let whole = Int(months.rounded(.up))
        return calendar.date(byAdding: .month, value: whole, to: from) ?? from
    }

    /// The calendar year `months` from `from`.
    public static func arrivalYear(
        months: Double,
        from: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        calendar.component(.year, from: arrivalDate(months: months, from: from, calendar: calendar))
    }
}
