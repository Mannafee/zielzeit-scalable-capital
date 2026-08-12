import SwiftUI
import ZielzeitCore

// The top of the holdings page: the time thesis, then the allocation that
// backs it. Split out of HoldingsView, which was 812 lines across eleven views.

/// The page's visual thesis: gains are not just money, they are time returned.
struct HoldingsHeroCard: View {

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
struct TargetEcho: View {
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

struct YearChip: View {
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

struct HeroBadge: View {
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
struct PortfolioOverviewCard: View {

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

struct MoneyMetric: View {
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
