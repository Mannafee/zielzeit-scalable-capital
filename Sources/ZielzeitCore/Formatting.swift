import Foundation

/// Display formatting shared by the menu and the `--once` text output, so both
/// render identically from one set of rules.
public enum Format {

    /// Column width for the label in a projection or what-if row. Rows are
    /// drawn in a monospaced font, so padding is what lines the columns up.
    private static let labelWidth = 11
    private static let rateWidth = 7

    /// A narrow no-break space, used both between thousands and between a number
    /// and the unit that follows it.
    private static let thinSpace = "\u{202F}"

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    /// The bare number, grouped with a narrow space and with the decimal
    /// separator the current language asks for.
    ///
    /// The grouping separator is the app's own choice in both languages rather
    /// than the locale's, which is what keeps `1 234 567,89` readable at 10pt
    /// where `1.234.567,89` turns into a picket fence.
    private static func decimalString(_ value: Double, decimals: Int) -> String {
        let formatter = numberFormatter
        formatter.locale = AppLanguage.current.locale
        formatter.groupingSeparator = thinSpace
        formatter.usesGroupingSeparator = true
        // German would otherwise leave four-digit amounts ungrouped, so `1750 €`
        // sat beside `11 709,98 €` in the same popover. One rule for every
        // magnitude, as in English.
        formatter.minimumGroupingDigits = 1
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: value as NSNumber) ?? String(value)
    }

    /// An amount with the currency symbol where the language puts it: `€1 234` in
    /// English, `1 234 €` in German.
    public static func euro(_ amount: Double, decimals: Int = 0) -> String {
        let number = decimalString(amount, decimals: decimals)
        return AppLanguage.current.currencySymbolLeads ? "€\(number)" : "\(number)\(thinSpace)€"
    }

    /// Signed amount using a real minus sign, e.g. `+€1 819` / `−€240`.
    public static func signedEuro(_ amount: Double, decimals: Int = 0) -> String {
        (amount >= 0 ? "+" : "−") + euro(abs(amount), decimals: decimals)
    }

    /// A rate, e.g. `6.0%` — or `6,0 %` in German, where the space before the
    /// sign is the convention rather than a typo.
    public static func percent(_ rate: Double, decimals: Int = 1) -> String {
        switch AppLanguage.current {
        case .english:
            return String(format: "%.\(decimals)f%%", rate * 100)
        case .german:
            return decimalString(rate * 100, decimals: decimals) + thinSpace + "%"
        }
    }

    /// A whole percentage for the tightest places: the menu bar title and the
    /// label beside the progress bar.
    public static func wholePercent(_ fraction: Double) -> String {
        let value = Int((fraction * 100).rounded())
        return AppLanguage.current == .german ? "\(value)\(thinSpace)%" : "\(value)%"
    }

    /// A number of weeks, for the holdings page's time contributions.
    ///
    /// One decimal, and unsigned: on that page the sign is carried by the wording
    /// ("earlier" / "later") and by which side of the axis a bar grows from, so a
    /// minus here would state it a third time — and, next to the word "later", state
    /// it backwards.
    ///
    /// Branches on the language rather than going through the shared formatter, for
    /// the same reason `years` does: a number that sits directly against a word
    /// takes the separator of the language that wrote the word, not of the Mac's
    /// region. On a machine set to English with German formats, the alternative puts
    /// `21,6` next to `weeks`.
    public static func weeks(_ weeks: Double) -> String {
        switch AppLanguage.current {
        case .english: return String(format: "%.1f", abs(weeks))
        case .german: return decimalString(abs(weeks), decimals: 1)
        }
    }

    /// A difference between two percentages, e.g. `-5.5` for −5.5 pp.
    ///
    /// Signed, unlike `percent`: a gap's direction is the whole content of the
    /// figure, and the unit is written by the caller because "pp" and "PP" differ
    /// between the two languages.
    public static func percentagePoints(_ fraction: Double, decimals: Int = 1) -> String {
        let value = fraction * 100
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        switch AppLanguage.current {
        case .english: return sign + String(format: "%.\(decimals)f", abs(value))
        case .german: return sign + decimalString(abs(value), decimals: decimals)
        }
    }

    /// An abbreviated span for a data column, e.g. `11.6 yrs` / `11,6 J.`
    public static func years(_ months: Double) -> String {
        switch AppLanguage.current {
        case .english: return String(format: "%.1f yrs", months / 12)
        case .german: return decimalString(months / 12, decimals: 1) + " J."
        }
    }

    /// A duration for prose rather than a data row, e.g. `15.7 years`.
    ///
    /// Short horizons are given in months: "1.5 years" is a stranger way to say
    /// eighteen months, and a decimal fraction of a year reads as false precision
    /// when the whole number is small.
    ///
    /// German is given in the dative, because the one place this is used is the
    /// hero sentence that opens with "In …" — "In 15,6 Jahre" is wrong in a way
    /// no reader would forgive, and there is no second call site to keep
    /// nominative for.
    public static func duration(months: Double) -> String {
        switch AppLanguage.current {
        case .english:
            if months < 1 { return "under a month" }
            if months < 24 {
                let whole = Int(months.rounded())
                return whole == 1 ? "1 month" : "\(whole) months"
            }
            return String(format: "%.1f years", months / 12)
        case .german:
            if months < 1 { return "unter einem Monat" }
            if months < 24 {
                let whole = Int(months.rounded())
                return whole == 1 ? "einem Monat" : "\(whole) Monaten"
            }
            return decimalString(months / 12, decimals: 1) + " Jahren"
        }
    }

    /// The broker's valuation time, dated only when it is not from today.
    ///
    /// A bare `21:00` beside figures struck on Friday reads as this evening, so the
    /// day comes along whenever it is not today's — and stays out of the way when it
    /// is, which is most of the time during the week.
    public static func valuationStamp(
        _ date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let time = dateFormatter(template: "j:mm").string(from: date)
        guard !calendar.isDate(date, inSameDayAs: now) else { return time }
        return "\(dateFormatter(template: "d MMM").string(from: date)) \(time)"
    }

    /// Built per call rather than held as a static, because the template has to be
    /// applied *after* the locale — a formatter configured once at launch would
    /// keep whichever language happened to be current then.
    private static func dateFormatter(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    /// Direction as a glyph. Empty for `flat`: an arrow beside a figure that rounds
    /// to zero claims a move the number does not show.
    public static func arrow(_ direction: MoveDirection) -> String {
        switch direction {
        case .up: return "▲"
        case .down: return "▼"
        case .flat: return ""
        }
    }

    /// The compact market chip, e.g. `▲ €10,07 this week`.
    ///
    /// The window is always named. The sign differs between windows on a real
    /// account — up on the week, down on the month — so an unlabelled arrow would
    /// be an editorial choice pretending to be a fact.
    public static func moveChip(_ move: MarketMove) -> String {
        let glyph = arrow(move.direction)
        let amount = signedEuro(move.gain, decimals: 2)
        return glyph.isEmpty ? "\(amount) \(move.windowLabel)" : "\(glyph) \(amount) \(move.windowLabel)"
    }

    /// One market row for the text output, e.g. `this week    ▲  +€10,07   +0.1%`.
    ///
    /// The label column is two wider than elsewhere: "last session" is exactly
    /// `labelWidth + 1` characters, so at the usual width it butts straight against
    /// the arrow with no space at all.
    public static func moveRow(_ move: MarketMove) -> String {
        let label = pad(move.windowLabel, to: labelWidth + 3)
        let glyph = pad(arrow(move.direction), to: 2)
        let amount = pad(signedEuro(move.gain, decimals: 2), to: 12)
        guard let fraction = move.fraction else { return "\(label)\(glyph) \(amount)" }
        let sign = fraction >= 0 ? "+" : "−"
        return "\(label)\(glyph) \(amount) \(sign)\(percent(abs(fraction)))"
    }

    /// One projection row, e.g. `Moderate    6.0%   2038  (11.6 yrs)`.
    public static func scenarioRow(_ scenario: Scenario) -> String {
        let label = pad(scenario.label, to: labelWidth)
        guard let rate = scenario.annualRate else {
            return "\(label) \(pad("—", to: rateWidth)) \(Strings.notEnoughHistory)"
        }
        let ratePart = pad(percent(rate), to: rateWidth)
        guard let months = scenario.months, let year = scenario.year else {
            return "\(label) \(ratePart) \(Strings.neverAtThisPace)"
        }
        if months == 0 {
            return "\(label) \(ratePart) \(Strings.reached) 🎉"
        }
        return "\(label) \(ratePart) \(year)  (\(years(months)))"
    }

    /// One what-if row, e.g. `+€100/mo    2036  (−1.8 yrs)`.
    public static func whatIfRow(_ whatIf: WhatIf) -> String {
        let label = pad("+\(euro(whatIf.extraPerMonth))\(Strings.perMonth)", to: labelWidth + rateWidth + 1)
        guard let year = whatIf.year else { return "\(label) \(Strings.never)" }
        guard let saved = whatIf.yearsSaved, saved > 0.05 else { return "\(label) \(year)" }
        return "\(label) \(year)  (−\(years(saved * 12)))"
    }

    /// One "to reach it by" row, e.g. `end of 2028    €770/mo  (+€358)`.
    public static func requiredRow(_ row: (year: Int, required: Double?, delta: Double?)) -> String {
        let label = pad(Strings.endOf(row.year), to: labelWidth + rateWidth + 1)
        guard let required = row.required else { return "\(label) —" }
        guard required > 0 else { return "\(label) \(Strings.nothingGrowthGetsThere)" }
        let amount = pad("\(euro(required))\(Strings.perMonth)", to: 12)
        guard let delta = row.delta, abs(delta) >= 1 else { return "\(label) \(amount)" }
        return "\(label) \(amount) (\(signedEuro(delta)) \(Strings.versusNow))"
    }

    /// A labelled summary row, e.g. `Portfolio   €11 795.78`.
    public static func summaryRow(_ label: String, _ value: String) -> String {
        "\(pad(label, to: labelWidth + 1))\(value)"
    }

    /// Pads to a column width, always leaving at least one trailing space.
    ///
    /// The floor matters once the labels are translated: `letzter Schluss` is
    /// wider than the market column, and without it the label would butt straight
    /// against the arrow that follows. No English label reaches its column width,
    /// so the English output is unchanged.
    private static func pad(_ text: String, to width: Int) -> String {
        let padding = max(width - text.count, 1)
        return text + String(repeating: " ", count: padding)
    }
}
