import SwiftUI
import ZielzeitCore

// The per-position half of the holdings page: what each holding did, and the
// one sentence drawn from it. Split out of HoldingsView.

/// Share, return, and time contribution live together so each position tells one story.
struct PositionImpactSection: View {

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

struct PositionImpactRow: View {

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

struct ImpactBar: View {
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
struct PortfolioInsight: View {
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
