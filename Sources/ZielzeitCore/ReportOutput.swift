import Foundation

// Report as words: the menu bar title, the popover's rows, and --once.

extension Report {

    // MARK: - Menu bar title

    /// The compact one-line summary, e.g. `🎯 12% · 2037`.
    ///
    /// Used by the text output. The menu bar itself draws a progress ring and
    /// shows `menuBarText` beside it.
    public var statusTitle: String {
        if isGoalReached { return "🎯 \(Format.wholePercent(1)) · \(Strings.reached)" }
        let percent = Format.wholePercent(progress)
        guard let headlineYear else { return "🎯 \(percent) · —" }
        return "🎯 \(percent) · \(headlineYear)"
    }

    /// What sits next to the menu bar ring: the year, and nothing else.
    ///
    /// The percentage is what the ring is for, so repeating it as text would
    /// just make the menu bar noisy.
    public var menuBarText: String {
        if isGoalReached { return Strings.reachedCapitalized }
        guard let headlineYear else { return "—" }
        return String(headlineYear)
    }

    // MARK: - Row models
    //
    // Both the menu and the text output build from these, so the two renderings
    // can never drift apart.

    /// One row of the facts list.
    ///
    /// `kind` exists so the view can pick a symbol and a tint without matching on
    /// the label, which is now translated — an icon that disappears in German is
    /// exactly the kind of breakage a string comparison invites.
    public struct SummaryRow: Equatable {
        public enum Kind: String, Equatable, Sendable {
            case portfolio
            case saving
            case pastYear
        }

        public let kind: Kind
        public let label: String
        public let value: String
    }

    /// The labelled summary rows at the top of the menu.
    public var summaryRows: [SummaryRow] {
        // Goal and Remaining deliberately absent: the hero already states the goal
        // amount in prose and the bar states the percentage, so both rows were
        // restating the top of the popover in a smaller font.
        var rows: [SummaryRow] = [
            SummaryRow(
                kind: .portfolio,
                label: Strings.portfolio,
                value: Format.euro(snapshot.total, decimals: 2)
            ),
        ]

        var saving = "\(Format.euro(snapshot.monthlySavings, decimals: 2))\(Strings.perMonth)"
        var notes: [String] = []
        if snapshot.savingsPlanCount > 0 {
            notes.append(Strings.savingsPlans(snapshot.savingsPlanCount))
        }
        // Worth showing rather than leaving implicit: it is the difference between
        // a flat contribution and one that keeps pace with inflation, and every
        // projected year on screen depends on it.
        if snapshot.dynamizationRate > 0 {
            notes.append("+\(Format.percent(snapshot.dynamizationRate, decimals: 0))\(Strings.perYear)")
        }
        if !notes.isEmpty {
            saving += "  (\(notes.joined(separator: " · ")))"
        }
        rows.append(SummaryRow(kind: .saving, label: Strings.saving, value: saving))

        if let gain = snapshot.oneYearGain {
            rows.append(SummaryRow(
                kind: .pastYear,
                label: Strings.pastYear,
                value: Format.signedEuro(gain, decimals: 2)
            ))
        }
        return rows
    }

    /// Heading for the what-if section.
    public var whatIfHeading: String {
        Strings.whatIfHeading(rate: Format.percent(headlineRate))
    }

    /// A plain-text rendering of the whole menu, so the app can be checked from
    /// a terminal without launching the UI.
    public func textReport() -> String {
        var lines = [statusTitle, ""]
        lines += summaryRows.map { Format.summaryRow($0.label, $0.value) }

        let moves = self.moves
        if !moves.isEmpty {
            lines += ["", Strings.marketHeading]
            lines += moves.map { "  " + Format.moveRow($0) }
        }

        lines += ["", Strings.projectionsHeading]
        lines += scenarios.map { "  " + Format.scenarioRow($0) }
        if let real = realGoalValue, let year = headlineYear {
            lines += ["", Strings.todaysMoneyHeading]
            lines += ["  " + Strings.todaysMoneyLine(
                goal: Format.euro(goal),
                year: year,
                real: Format.euro(real),
                inflation: Format.percent(Projection.assumedInflation, decimals: 0)
            )]
        }

        if !isGoalReached {
            lines += ["", whatIfHeading]
            lines += whatIfs.map { "  " + Format.whatIfRow($0) }

            lines += ["", Strings.toReachItByHeading]
            lines += requiredSavingsRows.map { "  " + Format.requiredRow($0) }
        }
        lines += [""] + Disclaimer.textBlock(for: self)
        return lines.joined(separator: "\n")
    }
}
