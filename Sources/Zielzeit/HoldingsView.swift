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
        // The popover's parent measures its ideal width while rasterizing. German
        // labels are wider than English, so pinning the real content width here keeps
        // one long row from expanding the page and being cropped on both sides.
        .frame(width: Theme.popoverWidth - (Theme.gutter * 2), alignment: .leading)
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
                HoldingsHeroCard(report: report)
                PortfolioOverviewCard(holdings: report.holdings)
                PositionImpactSection(report: report)
                PortfolioInsight(report: report)

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

// MARK: - The portfolio story

/// The page's visual thesis: gains are not just money, they are time returned.
private struct HoldingsHeroCard: View {

    let report: HoldingsReport

    @Environment(\.colorScheme) private var scheme

    private var weeks: Double? { report.contributions.totalWeeks }
    private var isPositive: Bool { (weeks ?? 0) >= 0 }
    private var tint: Color { isPositive ? Theme.accent : .red }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TargetEcho(tint: tint)
                .frame(width: 138, height: 138)
                .offset(x: 34, y: -42)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 11) {
                SectionLabel(text: Strings.marketGainsInTime)

                if let weeks {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Format.weeks(weeks))
                            .font(Theme.display(41))
                            .foregroundStyle(isPositive
                                ? AnyShapeStyle(Theme.accentGradient(scheme))
                                : AnyShapeStyle(Theme.lossGradient))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(Strings.weeksWord)
                                .font(Theme.numeric(13))
                            Text(isPositive ? Strings.closerToGoal : Strings.fartherFromGoal)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(Strings.noArrivalToMove)
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                yearJourney

                HStack(spacing: 7) {
                    HeroBadge(
                        symbol: isPositive ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                        text: Format.signedEuro(report.holdings.unrealisedGain, decimals: 2),
                        tint: tint
                    )
                    if let totalReturn = report.holdings.sinceBuyReturn {
                        HeroBadge(
                            symbol: "percent",
                            text: Format.percent(totalReturn),
                            tint: totalReturn >= 0 ? Theme.accent : .red
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(scheme == .dark ? 0.18 : 0.12), tint.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(scheme == .dark ? 0.28 : 0.20), lineWidth: 0.75)
                }
        }
        .frame(width: Theme.popoverWidth - (Theme.gutter * 2))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var yearJourney: some View {
        if report.yearsDiffer || report.arrivalYearWithoutGains == nil {
            HStack(spacing: 7) {
                YearChip(
                    year: report.arrivalYearWithoutGains.map(String.init) ?? Strings.withoutGainsNever,
                    label: Strings.withoutGains,
                    tint: .secondary,
                    emphasised: false
                )
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                YearChip(
                    year: report.arrivalYear.map(String.init) ?? "—",
                    label: Strings.yours,
                    tint: tint,
                    emphasised: true
                )
            }
        } else {
            HStack(spacing: 7) {
                YearChip(
                    year: report.arrivalYear.map(String.init) ?? "—",
                    label: Strings.yours,
                    tint: tint,
                    emphasised: true
                )
                Text(Strings.sameYearWithoutGains)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

/// A quiet echo of the app icon, giving the hero depth without introducing a new motif.
private struct TargetEcho: View {
    let tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.08), lineWidth: 1)
            Circle()
                .trim(from: 0.05, to: 0.63)
                .stroke(tint.opacity(0.24), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(15)
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 16, height: 16)
        }
    }
}

private struct YearChip: View {
    let year: String
    let label: String
    let tint: Color
    let emphasised: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(year)
                .font(Theme.numeric(emphasised ? 13 : 12, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(tint.opacity(emphasised ? 0.12 : 0.07))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
}

private struct HeroBadge: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(Theme.numeric(10, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background { Capsule().fill(tint.opacity(0.11)) }
    }
}

// MARK: - Portfolio map

/// One unmistakable allocation mark, followed by the three numbers that explain it.
private struct PortfolioOverviewCard: View {

    let holdings: HoldingsSnapshot

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: Strings.theWholePortfolio)
                Spacer()
                Text(Strings.positionCount(holdings.items.count))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            GeometryReader { geometry in
                HStack(spacing: 3) {
                    ForEach(holdings.byValuation) { holding in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(shade(holding))
                            .frame(width: width(for: holding, in: geometry.size.width))
                    }
                }
            }
            .frame(height: 17)

            HStack(spacing: 0) {
                MoneyMetric(label: Strings.invested, value: Format.euro(holdings.cost))
                metricDivider
                MoneyMetric(
                    label: Strings.marketGain,
                    value: Format.signedEuro(holdings.unrealisedGain),
                    tint: holdings.unrealisedGain >= 0 ? Theme.accent : .red
                )
                metricDivider
                MoneyMetric(
                    label: Strings.totalReturn,
                    value: holdings.sinceBuyReturn.map { Format.percent($0) } ?? "—",
                    tint: (holdings.sinceBuyReturn ?? 0) >= 0 ? Theme.accent : .red
                )
            }
        }
        .padding(12)
        .dashboardCard()
        .frame(width: Theme.popoverWidth - (Theme.gutter * 2))
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 0.5, height: 28)
            .padding(.horizontal, 8)
    }

    private func shade(_ holding: Holding) -> Color {
        HoldingPalette.shade(for: holding, in: holdings, dark: scheme == .dark)
    }

    private func width(for holding: Holding, in total: Double) -> Double {
        guard let weight = holdings.weight(of: holding) else { return 0 }
        let gaps = Double(max(holdings.items.count - 1, 0)) * 3
        return max((total - gaps) * weight, 3)
    }
}

private struct MoneyMetric: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.25)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(Theme.numeric(11, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Position impact

/// Share, return, and time contribution live together so each position tells one story.
private struct PositionImpactSection: View {

    let report: HoldingsReport

    @Environment(\.colorScheme) private var scheme

    private var items: [TimeContribution] {
        report.contributions.isEmpty
            ? report.holdings.byValuation.map { TimeContribution(holding: $0, weeks: nil) }
            : report.contributions.ranked
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: Strings.positionImpact)
                Spacer()
                Text(Strings.positionImpactLegend)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 0) {
                ForEach(items) { item in
                    PositionImpactRow(
                        item: item,
                        holdings: report.holdings,
                        peakWeeks: report.contributions.peakWeeks,
                        isOutlier: item.holding == report.outlier,
                        tint: HoldingPalette.shade(
                            for: item.holding,
                            in: report.holdings,
                            dark: scheme == .dark
                        )
                    )

                    if item.id != items.last?.id {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(height: 0.5)
                            .padding(.leading, 30)
                    }
                }
            }
            .dashboardCard()
        }
        .frame(width: Theme.popoverWidth - (Theme.gutter * 2))
    }
}

private struct PositionImpactRow: View {

    let item: TimeContribution
    let holdings: HoldingsSnapshot
    let peakWeeks: Double?
    let isOutlier: Bool
    let tint: Color

    private var holding: Holding { item.holding }
    private var returnTint: Color {
        guard let value = holding.sinceBuyReturn else { return .secondary }
        return value >= 0 ? Theme.accent : .red
    }
    private var timeTint: Color {
        guard let weeks = item.weeks else { return .secondary }
        return weeks >= 0 ? Theme.accent : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tint)
                    .frame(width: 10, height: 10)

                Text(HoldingName.short(holding.name))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isOutlier {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.warning)
                }

                Spacer(minLength: 5)

                Text(Format.euro(holding.valuation))
                    .font(Theme.numeric(10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 7) {
                if let weight = holdings.weight(of: holding) {
                    Text(Format.wholePercent(weight))
                        .font(Theme.numeric(9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(Strings.ofPortfolio)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Text("·")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)

                Text(holding.sinceBuyReturn.map { Format.percent($0) } ?? "—")
                    .font(Theme.numeric(9, weight: .semibold))
                    .foregroundStyle(returnTint)

                Spacer()

                Image(systemName: "clock")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(timeTint)
                Text(timeLabel)
                    .font(Theme.numeric(9, weight: .semibold))
                    .foregroundStyle(timeTint)
            }

            ImpactBar(weeks: item.weeks, peak: peakWeeks, tint: tint)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(isOutlier ? Theme.warning.opacity(0.045) : .clear)
        .help("\(holding.name) · \(holding.isin)")
        .accessibilityElement(children: .combine)
    }

    private var timeLabel: String {
        guard let weeks = item.weeks else { return Strings.withoutItNoArrival }
        return "\(Format.weeks(weeks)) \(Strings.weeksAbbreviated)"
    }
}

private struct ImpactBar: View {
    let weeks: Double?
    let peak: Double?
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                if let weeks, let peak, peak > 0 {
                    Capsule()
                        .fill(weeks >= 0 ? AnyShapeStyle(tint) : AnyShapeStyle(Theme.lossGradient))
                        .frame(width: max(3, min(abs(weeks) / peak, 1) * geometry.size.width))
                }
            }
        }
        .frame(height: 3)
    }
}

/// Turns the existing outlier calculation into a sentence a person can act on.
private struct PortfolioInsight: View {
    let report: HoldingsReport

    var body: some View {
        if let outlier = report.outlier,
           let ownReturn = outlier.sinceBuyReturn,
           let portfolioReturn = report.holdings.sinceBuyReturn {
            let delta = ownReturn - portfolioReturn
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.warning)
                    .frame(width: 18, height: 18)
                    .background { Circle().fill(Theme.warning.opacity(0.12)) }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.worthNoticing)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.25)
                        .foregroundStyle(Theme.warning)
                    Text(Strings.outlierInsight(
                        HoldingName.short(outlier.name),
                        gap: pointGap(abs(delta)),
                        isAhead: delta > 0
                    ))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Theme.warning.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Theme.warning.opacity(0.16), lineWidth: 0.5)
                    }
            }
            .frame(width: Theme.popoverWidth - (Theme.gutter * 2), alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func pointGap(_ value: Double) -> String {
        let signed = Format.percentagePoints(value)
        return signed.hasPrefix("+") ? String(signed.dropFirst()) : signed
    }
}

private extension View {
    func dashboardCard() -> some View {
        background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.quaternary, lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.035), radius: 8, y: 3)
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
