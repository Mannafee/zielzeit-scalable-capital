import SwiftUI
import ZielzeitCore

/// The three scenarios as rows, with the headline one highlighted.
struct ScenarioListView: View {

    let report: Report
    let extraSavings: Double

    var body: some View {
        VStack(spacing: 2) {
            ForEach(report.scenarios, id: \.label) { scenario in
                ScenarioRow(
                    scenario: scenario,
                    year: year(for: scenario),
                    isHeadline: scenario.label == report.headlineLabel
                )
            }
        }
    }

    /// Scenario years follow the slider, so the list and the chart agree.
    private func year(for scenario: Scenario) -> Int? {
        guard let rate = scenario.annualRate else { return nil }
        guard extraSavings > 0 else { return scenario.year }
        return report.arrival(extraMonthlySavings: extraSavings, annualRate: rate).year
    }
}

private struct ScenarioRow: View {

    let scenario: Scenario
    let year: Int?
    let isHeadline: Bool

    private var tint: Color { Theme.color(forScenario: scenario.label) }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .shadow(color: tint.opacity(0.5), radius: 2)

            Text(scenario.label)
                .font(Theme.body.weight(isHeadline ? .semibold : .regular))
                .foregroundStyle(isHeadline ? .primary : .secondary)

            if let rate = scenario.annualRate {
                Text(Format.percent(rate))
                    .font(Theme.numeric(10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(tint.opacity(0.12), in: Capsule())
            }

            Spacer(minLength: 4)

            value
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            if isHeadline {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.10))
            }
        }
    }

    @ViewBuilder
    private var value: some View {
        if scenario.annualRate == nil {
            Text(Strings.noHistory)
                .font(Theme.caption)
                .foregroundStyle(.tertiary)
        } else if let year {
            Text(String(year))
                .font(Theme.numeric(13, weight: isHeadline ? .bold : .medium))
                .foregroundStyle(isHeadline ? tint : .primary.opacity(0.8))
                .contentTransition(.numericText())
        } else {
            Text(Strings.never)
                .font(Theme.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
