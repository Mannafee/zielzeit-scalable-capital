import SwiftUI
import ZielzeitCore

// The popover's secondary panels: the figures under the chart, and what the
// page shows when there are none to give.

/// The raw numbers, small and secondary — the chart is the headline, these are
/// for when you want to check the arithmetic.
struct PortfolioFactsView: View {

    let report: Report

    var body: some View {
        VStack(spacing: 4) {
            ForEach(report.summaryRows, id: \.kind) { row in
                HStack(spacing: 7) {
                    // Fixed width, and reserved even when a row has no symbol, so
                    // the labels stay in one column whatever the rows are.
                    Image(systemName: symbol(for: row.kind) ?? "circle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(iconTint(for: row.kind))
                        .opacity(symbol(for: row.kind) == nil ? 0 : 1)
                        .frame(width: 13)

                    Text(row.label)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.value)
                        .font(Theme.numeric(11, weight: .medium))
                        .foregroundStyle(tint(for: row.kind))
                }
            }
        }
    }

    /// Symbols are chosen per row rather than carried in `Report`, which holds no
    /// UI. Keyed off `kind` rather than the label, which is translated.
    private func symbol(for kind: Report.SummaryRow.Kind) -> String? {
        switch kind {
        case .portfolio: return "briefcase"
        // The recurring deposit, not an amount — a euro glyph here would just
        // repeat the figure at the other end of the row.
        case .saving: return "repeat"
        case .pastYear:
            return (report.snapshot.oneYearGain ?? 0) >= 0
                ? "chart.line.uptrend.xyaxis"
                : "chart.line.downtrend.xyaxis"
        }
    }

    /// Quiet by default. The past-year row takes its value's colour, so the glyph,
    /// the direction of the line in it and the sign of the number all agree.
    private func iconTint(for kind: Report.SummaryRow.Kind) -> Color {
        kind == .pastYear ? tint(for: kind) : .secondary.opacity(0.55)
    }

    private func tint(for kind: Report.SummaryRow.Kind) -> Color {
        guard kind == .pastYear, let gain = report.snapshot.oneYearGain else {
            return .primary.opacity(0.85)
        }
        return gain >= 0 ? Theme.accent : .red
    }
}

/// Shared empty/error presentation.
struct EmptyStateView: View {

    let symbol: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(.system(size: 15, weight: .semibold))

            Text(message)
                .font(Theme.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .padding(.top, 2)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LoadingView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(Strings.readingPortfolio)
                .font(Theme.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
