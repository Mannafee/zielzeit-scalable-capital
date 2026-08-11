import SwiftUI
import ZielzeitCore

/// The holdings page: three readings of the same positions.
///
/// Ordered by what the app is for. Time first, because that is the unit the whole app
/// converts money into; then what the money is; then how each part of it has done.
///
/// It was five readings for a while. A diversification panel and the broker's stress
/// scenarios were cut for answering questions this app does not ask, and a
/// what-a-crash-costs panel that replaced them went too — three sections that each
/// say something is worth more than five where two are filler.
struct HoldingsView: View {

    let state: HoldingsState
    /// Why the last refresh failed, while the figures below are the last good ones.
    var staleReason: String?

    /// How much room the pager is giving this page — the height of the page beside
    /// it, so both are the same size and swiping between them does not resize the
    /// popover. `nil` when there is no pager, in which case the page takes what it
    /// needs up to the screen's limit.
    var availableHeight: CGFloat?

    let onBack: () -> Void
    let onRetry: () -> Void

    @Environment(\.isRasterizing) private var isRasterizing

    /// The scrolling content's full height, so the fade at the bottom edge appears
    /// only when there is actually something below it.
    @State private var contentHeight: CGFloat = 0

    /// How many points of page remain below the fold. Drives the chevron, which has
    /// to disappear once there is nothing left to scroll to — a permanent "more
    /// below" arrow at the end of a page is a lie about the page.
    @State private var distanceBelow: CGFloat = 0

    /// How tall the scrolling part may get.
    ///
    /// Matches the projection page when the pager offers a height, so the two pages
    /// are one size. Anything that does not fit scrolls — which, now that the page is
    /// three sections rather than five, is usually nothing.
    ///
    /// The fallback is the display: a popover taller than the screen does not scroll,
    /// AppKit clips it, and what it clips is the top, where the only way back is.
    /// Bounded at both ends, so a very tall display does not produce a popover the
    /// length of the screen and a very short one still gets a usable page.
    private var maxContentHeight: CGFloat {
        if let availableHeight {
            // What is left after this page's own header and the gap beneath it.
            return max(availableHeight - Self.headerAllowance, 240)
        }
        let chrome: CGFloat = 150
        let available = (NSScreen.main?.visibleFrame.height ?? 800) - chrome
        return min(max(available, 320), 720)
    }

    /// The header row plus the spacing under it, which the scrolling area does not
    /// get. Measured rather than guessed would be better; it is a constant because
    /// the header is one line of fixed type and has been since it was written.
    private static let headerAllowance: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Outside the scroll view on purpose: the back arrow has to stay
            // reachable no matter how far down the page you are.
            header

            if isRasterizing {
                // `--render` only: laid out at full height so the whole page lands
                // in the PNG. See `EnvironmentValues.isRasterizing`.
                VStack(alignment: .leading, spacing: 14) {
                    sections
                }
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 14) {
                        sections
                    }
                    // Keeps the last section clear of the seam above the footer.
                    .padding(.bottom, 2)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        contentHeight = height
                    }
                }
                .frame(maxHeight: maxContentHeight)
                // No rubber-banding on a page that already fits.
                .scrollBounceBehavior(.basedOnSize)
                // `.never`, not `.hidden`: with "Show scroll bars" left on Automatic
                // and a mouse attached, macOS draws the permanent legacy scroller —
                // fifteen points of chrome down the side of a popover that is only
                // 344 wide. The fade and the chevron below say "there is more"
                // instead, which is the only job the bar was doing here.
                .scrollIndicators(.never)
                .mask(bottomFade)
                // How much is still below, so the cue can appear only while there is
                // somewhere to go and get out of the way at the end of the page.
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentSize.height
                        - (geometry.contentOffset.y + geometry.containerSize.height)
                } action: { _, remaining in
                    distanceBelow = remaining
                }
                .overlay(alignment: .bottom) { moreBelowCue }
            }
        }
    }

    @ViewBuilder
    private var sections: some View {
        Group {
            switch state {
            case .ready(let report) where report.isEmpty:
                EmptyStateView(
                    symbol: "tray",
                    title: Strings.noHoldings,
                    message: Strings.noHoldingsMessage,
                    actionTitle: Strings.tryAgain,
                    action: onRetry
                )
            case .ready(let report):
                TimeContributionSection(report: report)
                Seam()
                PortfolioBarSection(holdings: report.holdings)
                Seam()
                SinceBuySection(report: report)

                if report.holdings.hasOutdatedQuote {
                    note(Strings.quoteOutdated, symbol: "clock.arrow.circlepath")
                }
                if let staleReason {
                    note(Strings.couldNotUpdate(staleReason), symbol: "exclamationmark.triangle.fill")
                }
            case .loading, .idle:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(Strings.readingHoldings)
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            case .failure(let message):
                EmptyStateView(
                    symbol: "exclamationmark.triangle",
                    title: Strings.cantReadHoldings,
                    message: message,
                    actionTitle: Strings.tryAgain,
                    action: onRetry,
                    tint: .orange
                )
            }
        }
    }

    /// The back arrow and the page's name. The arrow is the only way out, so it is
    /// a real target rather than a glyph beside the title.
    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(FooterButtonStyle())
            .help(Strings.back)

            Text(Strings.holdings)
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            if case .ready(let report) = state {
                // To the cent, like the popover's own Portfolio row. This is the
                // figure a reader checks against their broker, and whole euros put
                // it up to fifty cents away from both — the same portfolio read as
                // two different numbers one tap apart.
                Text(Format.euro(report.holdings.total, decimals: 2))
                    .font(Theme.numeric(12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Softens the last few points of the scrolling area, so content passes under an
    /// edge rather than being sliced by one.
    ///
    /// Only when the page overflows: a fade over content that already fits would dim
    /// the last row for no reason. Kept to twelve points and never fully transparent
    /// at the bottom, because `mask` takes hit testing with it and a control in that
    /// strip still has to be clickable.
    private var bottomFade: LinearGradient {
        let overflows = contentHeight > maxContentHeight + 1
        return LinearGradient(
            stops: overflows
                ? [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.93),
                    .init(color: .black.opacity(0.15), location: 1),
                ]
                : [.init(color: .black, location: 0), .init(color: .black, location: 1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A chevron saying the page continues, shown only while it does.
    ///
    /// The fade alone was not enough: a soft edge reads as a design flourish, and the
    /// scroll bar it replaced was the only thing telling anyone the page went further.
    /// This is small, it points, and it goes away — it fades out over the last stretch
    /// rather than at the very end, so it is already gone by the time you arrive
    /// instead of vanishing under the cursor.
    @ViewBuilder
    private var moreBelowCue: some View {
        let visible = min(max(distanceBelow - Self.cueFadeDistance, 0) / Self.cueFadeDistance, 1)
        Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule().fill(.quaternary)
            }
            .opacity(visible)
            .padding(.bottom, 1)
            // Decoration for a gesture, and a duplicate of the scroll position for
            // anyone using VoiceOver, which announces that itself.
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.15), value: visible)
    }

    /// Over how many points the cue fades. Twice this much below the fold and it is
    /// fully opaque; at this much or less it is gone.
    private static let cueFadeDistance: CGFloat = 24

    /// A caveat about the figures above, said once for the page rather than marked
    /// on each row: both of these are about every number here, not about one of them.
    private func note(_ text: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.orange)
    }
}

// MARK: - 1. What bought you time

/// Each holding's gain, converted into how much earlier the goal arrives.
private struct TimeContributionSection: View {

    let report: HoldingsReport

    @Environment(\.colorScheme) private var scheme

    private var contributions: TimeContributions { report.contributions }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: Strings.whatBoughtYouTime)

            if contributions.isEmpty {
                Text(Strings.noArrivalToMove)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                hero
                rows
            }
        }
    }

    /// The two years, side by side.
    ///
    /// The page used to lead with "8.8 weeks earlier", which is a quantity nobody has
    /// a feel for. This states the same fact in the unit the rest of the app has spent
    /// its life teaching: the year you are on course for, against the year you would be
    /// on course for if the market had given you nothing. The weeks stay, underneath,
    /// as the precise version of the gap between them.
    @ViewBuilder
    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Two years only when they are genuinely two. On a six-figure goal a few
            // thousand euros of gains is worth weeks, so most of the time both sides
            // land in the same year — and "2038 → 2038" with an arrow between them
            // reads as "your gains bought you nothing", which is both discouraging
            // and false. When they do differ, the pair is the strongest thing this
            // page can say, so it gets the full treatment.
            if report.yearsDiffer || report.arrivalYearWithoutGains == nil {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    yearColumn(
                        value: report.arrivalYear.map(String.init) ?? "—",
                        caption: Strings.yours,
                        emphasised: true
                    )

                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 12)

                    yearColumn(
                        value: report.arrivalYearWithoutGains.map(String.init)
                            ?? Strings.withoutGainsNever,
                        caption: Strings.withoutGains,
                        emphasised: false
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(report.arrivalYear.map(String.init) ?? "—")
                        .font(Theme.display(34))
                        .foregroundStyle(Theme.accentGradient(scheme))
                    Text(Strings.sameYearWithoutGains)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let weeks = contributions.totalWeeks {
                HStack(spacing: 5) {
                    Image(systemName: weeks >= 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(weeks >= 0
                        ? Strings.weeksEarlier(Format.weeks(abs(weeks)))
                        : Strings.weeksLater(Format.weeks(abs(weeks))))
                        .font(Theme.numeric(11, weight: .semibold))
                    // The same quantity the "Earned" swatch states, rendered the same
                    // way: one number, one spelling.
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(Format.signedEuro(report.holdings.unrealisedGain, decimals: 2))
                        .font(Theme.numeric(11, weight: .medium))
                }
                .foregroundStyle(Theme.accent)
            }
        }
    }

    /// One year and its caption. The reachable year wears the brand gradient at the
    /// size the projection page uses for its own; the counterfactual is deliberately
    /// smaller and grey, because it is the thing that did not happen.
    private func yearColumn(value: String, caption: String, emphasised: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if emphasised {
                Text(value)
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.accentGradient(scheme))
            } else {
                Text(value)
                    .font(Theme.display(22))
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
            Text(caption)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .fixedSize()
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(contributions.ranked) { item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(HoldingName.short(item.holding.name))
                            .font(Theme.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Text(label(for: item))
                            .font(Theme.numeric(11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    WeeksBar(
                        weeks: item.weeks,
                        peak: contributions.peakWeeks,
                        isTwoSided: contributions.hasNegative,
                        tint: HoldingPalette.shade(
                            for: item.holding, in: report.holdings, dark: scheme == .dark
                        )
                    )
                }
            }
        }
    }

    private func label(for item: TimeContribution) -> String {
        guard let weeks = item.weeks else { return Strings.withoutItNoArrival }
        return "\(Format.weeks(weeks)) \(Strings.weeksAbbreviated)"
    }
}

/// One holding's contribution, scaled against the largest on the page.
///
/// Grows from the left while every position is up, and from a centre axis as soon
/// as one is not: a position that is down subtracts time, and a bar that could only
/// grow rightward would have to draw a loss as a short gain. Paying for that axis
/// when nothing is negative would waste half of every track.
private struct WeeksBar: View {

    let weeks: Double?
    let peak: Double?
    let isTwoSided: Bool
    /// The fund's own shade, so this bar and its chip in the legend above are
    /// recognisably the same position.
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let origin = isTwoSided ? geometry.size.width / 2 : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 5)

                if let width = width(in: geometry.size.width), let weeks {
                    Capsule()
                        .fill(weeks >= 0 ? AnyShapeStyle(tint) : AnyShapeStyle(Theme.lossGradient))
                        .frame(width: width, height: 5)
                        .offset(x: weeks >= 0 ? origin : origin - width)
                }

                if isTwoSided {
                    // The axis, so a bar's direction is legible without reading the
                    // number beside it.
                    Rectangle()
                        .fill(.tertiary)
                        .frame(width: 1, height: 7)
                        .offset(x: origin)
                }
            }
        }
        .frame(height: 7)
    }

    private func width(in total: Double) -> Double? {
        guard let weeks, let peak, peak > 0 else { return nil }
        let available = isTwoSided ? total / 2 : total
        return min(abs(weeks) / peak, 1) * available
    }
}

// MARK: - 2. Your money, the market's

/// The whole portfolio as one mark, and the page's legend.
///
/// This replaced a second list of five bars. Three sections in a row of "label, five
/// rows, a bar each" made the page read as one idea repeated, and a stacked bar says
/// what those rows said — relative size — in a single glance, while naming each fund
/// once for every section below it to refer back to by colour.
private struct PortfolioBarSection: View {

    let holdings: HoldingsSnapshot

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(text: Strings.theWholePortfolio)

            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(holdings.byValuation) { holding in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(shade(holding))
                            .frame(width: width(for: holding, in: geometry.size.width))
                    }
                }
            }
            .frame(height: 13)

            legend

            // The header total split in two, so both are given to the cent: rounded,
            // they would sum to a euro that is not the one at the top of the page.
            HStack(spacing: 12) {
                Swatch(
                    color: .secondary.opacity(0.45),
                    label: Strings.paidIn(Format.euro(holdings.cost, decimals: 2))
                )
                Swatch(
                    color: Theme.accent,
                    label: Strings.earned(Format.signedEuro(holdings.unrealisedGain, decimals: 2))
                )
            }
        }
    }

    /// Names each fund once, with its shade and its share. Two columns, because five
    /// fund names down a single column is the row list this section exists to retire.
    private var legend: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(holdings.byValuation) { holding in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(shade(holding))
                        .frame(width: 7, height: 7)
                    Text(HoldingName.short(holding.name))
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 2)
                    if let weight = holdings.weight(of: holding) {
                        Text(Format.wholePercent(weight))
                            .font(Theme.numeric(10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .help("\(holding.name) · \(Format.euro(holding.valuation, decimals: 2))")
            }
        }
    }

    private func shade(_ holding: Holding) -> Color {
        HoldingPalette.shade(for: holding, in: holdings, dark: scheme == .dark)
    }

    /// Share of the bar, with a floor so a tiny position stays visible rather than
    /// collapsing into the gap beside it.
    private func width(for holding: Holding, in total: Double) -> Double {
        guard let weight = holdings.weight(of: holding) else { return 0 }
        let gaps = Double(max(holdings.items.count - 1, 0)) * 2
        return max((total - gaps) * weight, 3)
    }
}

private struct Swatch: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 3. Since you bought

/// Every position's return since purchase on one scale, against the portfolio's.
private struct SinceBuySection: View {

    let report: HoldingsReport

    @Environment(\.colorScheme) private var scheme

    private var rows: [(holding: Holding, fraction: Double)] {
        report.holdings.byValuation.compactMap { holding in
            holding.sinceBuyReturn.map { (holding, $0) }
        }
    }

    /// The axis covers every return plus zero, so a losing position has somewhere
    /// to sit and the portfolio line is never off the end.
    private var bounds: (low: Double, high: Double) {
        let values = rows.map(\.fraction) + [0, report.holdings.sinceBuyReturn ?? 0]
        let low = min(values.min() ?? 0, 0)
        let high = max(values.max() ?? 0, 0)
        // A flat portfolio would give a zero-width axis, which puts every dot on
        // top of the line and reads as a coincidence rather than as no spread.
        return high - low < 0.02 ? (low - 0.01, high + 0.01) : (low, high)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: Strings.sinceYouBought)

            if rows.isEmpty {
                Text(Strings.notEnoughHistory)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(rows, id: \.holding.id) { row in
                        StripRow(
                            holding: row.holding,
                            fraction: row.fraction,
                            bounds: bounds,
                            isOutlier: row.holding == report.outlier,
                            shade: HoldingPalette.shade(
                                for: row.holding, in: report.holdings, dark: scheme == .dark
                            )
                        )
                    }
                }

                if let portfolio = report.holdings.sinceBuyReturn {
                    Text(Strings.portfolioAt(Format.percent(portfolio)))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

/// One holding's return, as a dot on its own track.
///
/// A row each rather than five dots on a shared axis: four of a broad portfolio's
/// returns cluster within a few points, and on one line their labels collide into
/// something unreadable.
private struct StripRow: View {

    let holding: Holding
    let fraction: Double
    let bounds: (low: Double, high: Double)
    let isOutlier: Bool
    /// The fund's shade from the legend. Overridden by amber when this is the
    /// outlier: "look at this" outranks identity, and the row says which fund it is
    /// in words anyway.
    let shade: Color

    private var tint: Color { isOutlier ? Theme.warning : shade }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(HoldingName.short(holding.name))
                    .font(.system(size: 10))
                    .foregroundStyle(isOutlier ? tint : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(Format.percent(fraction))
                    .font(Theme.numeric(10, weight: .medium))
                    .foregroundStyle(isOutlier ? tint : .secondary)
            }

            GeometryReader { geometry in
                let span = bounds.high - bounds.low
                let x = span > 0 ? (fraction - bounds.low) / span * geometry.size.width : 0
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 1)
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                        .offset(x: min(max(x - 3.5, 0), geometry.size.width - 7))
                }
            }
            .frame(height: 7)
        }
    }
}

// MARK: - Names

enum HoldingName {

    /// Trims the issuer and the share-class suffix from a fund's legal name.
    ///
    /// A 344pt row cannot hold "iShares MSCI Emerging Markets IMI Screened (Acc)",
    /// and truncating it leaves five rows that all begin "iShares MSCI…" and differ
    /// only past the ellipsis. Dropping the parts that repeat is what makes the list
    /// scannable — the ISIN is what identifies a position exactly, and it is on the
    /// row's tooltip rather than in the name.
    static func short(_ name: String) -> String {
        var trimmed = name

        // Repeatedly, not once: "iShares MSCI Europe Screened" carries two of these
        // back to back, and stripping only the first leaves every row in the legend
        // starting "MSCI …" — which was the problem.
        var strippedSomething = true
        while strippedSomething {
            strippedSomething = false
            for prefix in issuers where trimmed.hasPrefix(prefix + " ") {
                trimmed.removeFirst(prefix.count + 1)
                strippedSomething = true
                break
            }
        }

        for suffix in shareClasses where trimmed.hasSuffix(suffix) {
            trimmed.removeLast(suffix.count)
            break
        }

        // Never returns nothing: a fund named exactly after its issuer would
        // otherwise reduce to an empty row.
        let short = trimmed.trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? name : short
    }

    /// Issuers common enough on a Scalable portfolio to be noise in a list of it.
    /// Not exhaustive by design: an unrecognised issuer keeps its name in full,
    /// which is worse-looking but never wrong.
    ///
    /// `MSCI` is in here for the same reason and not because it is an issuer: on a
    /// portfolio of broad index funds nearly every name starts with it, so in a
    /// two-column legend it is the word that pushes the part you need — Europe,
    /// Emerging Markets — out past the ellipsis. `FTSE` and `S&P` stay, because
    /// there they are the distinguishing part of the name rather than the prefix
    /// every row shares.
    private static let issuers = [
        "iShares", "Vanguard", "Invesco", "Xtrackers", "Amundi", "SPDR", "HSBC", "Franklin",
        "VanEck", "MSCI",
    ]

    private static let shareClasses = [" (Acc)", " (Dist)", " Acc", " Dist"]
}
