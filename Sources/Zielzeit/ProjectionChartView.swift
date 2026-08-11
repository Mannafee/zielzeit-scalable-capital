import Charts
import SwiftUI
import ZielzeitCore

/// The three scenarios racing to the goal line.
///
/// Every curve stops the moment it touches the goal, so the chart reads as
/// "who gets there first" rather than trailing off into irrelevant growth.
struct ProjectionChartView: View {

    let report: Report
    let extraSavings: Double

    private var curves: [Report.Curve] {
        report.curves(extraMonthlySavings: extraSavings)
    }

    private var horizon: Int {
        report.chartHorizonMonths(extraMonthlySavings: extraSavings)
    }

    /// The curve the headline follows, drawn with an area fill beneath it.
    private var headline: Report.Curve? {
        curves.first { $0.label == report.headlineLabel }
    }

    var body: some View {
        Chart {
            if let headline {
                ForEach(headline.points) { point in
                    AreaMark(
                        x: .value("Month", point.month),
                        y: .value("Balance", point.balance)
                    )
                    .foregroundStyle(Theme.areaGradient(forScenario: report.headlineLabel))
                    .interpolationMethod(.monotone)
                }
            }

            ForEach(curves) { curve in
                ForEach(curve.points) { point in
                    LineMark(
                        x: .value("Month", point.month),
                        y: .value("Balance", point.balance),
                        series: .value("Scenario", curve.label)
                    )
                    .foregroundStyle(Theme.color(forScenario: curve.label))
                    .lineStyle(StrokeStyle(lineWidth: curve.label == report.headlineLabel ? 2.4 : 1.4, lineCap: .round))
                    .interpolationMethod(.monotone)
                }

                // A dot where each scenario meets the goal. The curve's own last
                // point, which `balanceSeries` puts on the crossing rather than on
                // the sample after it — so the dot cannot sit a month or two past
                // the year annotated beside it.
                if let arrival = curve.arrivalMonths, let last = curve.points.last {
                    PointMark(
                        x: .value("Month", last.month),
                        y: .value("Balance", last.balance)
                    )
                    .symbolSize(curve.label == report.headlineLabel ? 60 : 26)
                    .foregroundStyle(Theme.color(forScenario: curve.label))
                    .annotation(position: annotationPosition(for: curve, arrival: arrival)) {
                        if curve.label == report.headlineLabel {
                            Text(String(Projection.arrivalYear(months: arrival, from: report.asOf)))
                                .font(Theme.numeric(9, weight: .bold))
                                .foregroundStyle(Theme.color(forScenario: curve.label))
                        }
                    }
                }
            }

            // Deliberately unlabelled. The hero states the goal amount directly
            // above the chart, so repeating it here put the same figure twice
            // within a few points of vertical space and weakened both. Curves
            // stopping dead on this line is enough to read it as the target.
            RuleMark(y: .value("Goal", report.goal))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .chartYScale(domain: 0...(report.goal * 1.06))
        .chartXScale(domain: 0...Double(max(horizon, 12)))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: xAxisMonths) { value in
                AxisGridLine()
                    .foregroundStyle(.quaternary.opacity(0.5))
                if let month = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(Projection.arrivalYear(months: month, from: report.asOf)))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 104)
        .animation(.snappy(duration: 0.35), value: extraSavings)
    }

    /// Four or five year ticks, whatever the horizon. Whole months, unlike the
    /// curves' own last point: a tick is a label, and a gridline between two
    /// months has nothing to say.
    private var xAxisMonths: [Double] {
        let ticks = 4
        let span = max(horizon, 12)
        let step = max(span / ticks, 1)
        return stride(from: 0, through: span, by: step).map(Double.init)
    }

    /// Keep the headline annotation from colliding with the goal line at the top
    /// of the plot.
    private func annotationPosition(for curve: Report.Curve, arrival: Double) -> AnnotationPosition {
        arrival > Double(horizon) * 0.75 ? .topLeading : .topTrailing
    }
}
