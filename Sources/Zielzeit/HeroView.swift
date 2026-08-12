import SwiftUI
import ZielzeitCore

/// The headline: how far along, and the year it lands.
struct HeroView: View {

    @Environment(\.colorScheme) private var colorScheme

    let report: Report
    /// The what-if slider's live projection, supplied only while it is off zero.
    let preview: Preview?
    /// How the portfolio moved over the window currently selected, if any is.
    var move: MarketMove?
    /// Advances the market chip's window; `nil` when there is nothing to rotate to.
    var onCycleWindow: (() -> Void)?

    /// What the slider is currently projecting. Both fields optional in their own
    /// right: an extra contribution can still leave a goal out of reach, and that
    /// has to read as "Not yet" rather than silently falling back to the headline.
    struct Preview {
        let months: Double?
        let year: Int?
    }

    private var isPreviewing: Bool { preview != nil }

    private var year: Int? {
        if let preview { return preview.year }
        return report.headlineYear
    }

    private var months: Double? {
        if let preview { return preview.months }
        return report.headlineMonths
    }

    /// Full width rather than beside a ring, and the ring is now a bar.
    ///
    /// A 66pt ring spends its space badly at the progress values this app actually
    /// shows: early in a long savings plan the arc is a nub on a near-empty track,
    /// which reads as a rendering fault rather than as "1%". It also took the
    /// third of the width that the sentence needed, forcing a large goal onto two
    /// lines. A bar is honest at any fraction — an empty bar looks like an empty
    /// bar — and giving the year the full width lets it grow and the sentence fit
    /// on one line.
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // The market chip shares this row rather than taking one of its own:
            // the label leaves the right-hand side empty, so the chip costs no
            // height at all, and the top-right corner is where a ticker reads
            // naturally.
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: report.isGoalReached ? Strings.goalReached : Strings.projected)
                Spacer(minLength: 8)
                if let move {
                    MarketChipView(move: move, onCycle: onCycleWindow)
                }
            }

            if report.isGoalReached {
                Text(Strings.done)
                    .font(Theme.display(38))
                    .foregroundStyle(Theme.accentGradient(colorScheme))
            } else if let year {
                Text(String(year))
                    .font(Theme.display(44))
                    .foregroundStyle(Theme.headlineGradient(forScenario: report.headlineLabel, colorScheme))
                    // Counts down with the sentence beneath it, so both figures
                    // travel the same direction on a drag rather than one rolling
                    // up while the other rolls down.
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.25), value: year)
            } else {
                Text(Strings.notYet)
                    .font(Theme.display(30))
                    .foregroundStyle(.secondary)
            }

            caption

            purchasingPower

            progress
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Progress toward the goal: the percentage, then the bar it labels.
    private var progress: some View {
        HStack(spacing: 9) {
            Text(Format.wholePercent(report.progress))
                .font(Theme.numeric(11, weight: .bold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                // Fixed width so the bar starts in the same place whether the
                // label reads 1% or 100% — wide enough for the latter, which
                // truncates to "10…" if this is set by eye from a low value.
                // German and French need extra room for the space before the sign.
                .frame(width: AppLanguage.current.percentSignIsSpaced ? 42 : 36, alignment: .leading)

            ProgressBar(progress: report.progress)
        }
    }

    /// The line that carries the promise: prose, with the two numbers that matter
    /// pulled out of it typographically.
    ///
    /// Built by concatenating `Text` runs rather than as one string, so the amount
    /// and the horizon can be weighted differently from the words joining them —
    /// the eye lands on "€1 000 000" and "15.6 years" and reads the sentence
    /// afterwards. The amount takes the goal's own emerald rather than the
    /// headline hue: the 44pt year directly above is already amber, and a second
    /// amber number beside it competes instead of complementing.
    ///
    /// Duration first so a large goal wraps *before* the amount rather than
    /// stranding "in" at the end of a line.
    private func projection(months: Double) -> Text {
        let connective = Theme.caption
        let figure = Theme.numeric(13, weight: .bold)

        return Text(Strings.sentenceIn)
            .font(connective)
            .foregroundStyle(.secondary)
        + Text(Format.duration(months: months))
            // While the slider is moving, the horizon is the number under the
            // hand: it takes the headline's own hue and a heavier weight so the
            // eye goes to the figure that is changing rather than hunting for it.
            .font(Theme.numeric(isPreviewing ? 13 : 12, weight: isPreviewing ? .bold : .semibold))
            .foregroundStyle(
                isPreviewing
                    ? AnyShapeStyle(Theme.color(forScenario: report.headlineLabel))
                    : AnyShapeStyle(.primary)
            )
        + Text(Strings.sentenceYouWillHave)
            .font(connective)
            .foregroundStyle(.secondary)
        + Text(Format.euro(report.goal))
            .font(figure)
            .foregroundStyle(Theme.accent)
    }

    /// What the goal will actually be worth, one size down from the sentence above.
    ///
    /// Subordinate on purpose — it qualifies the amount in the sentence rather than
    /// competing with it — but not hidden: over a fifteen-year horizon this is the
    /// largest gap between the headline and reality, larger than anything in the
    /// disclaimer, and a figure that only appears when expanded is a figure nobody
    /// sees. Absent while the slider is previewing, where two amounts moving at once
    /// is one too many.
    @ViewBuilder
    private var purchasingPower: some View {
        if !isPreviewing, let real = report.realGoalValue {
            (
                Text(Strings.thatsAbout)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                + Text(Format.euro(real))
                    .font(Theme.numeric(10, weight: .semibold))
                    .foregroundStyle(.secondary)
                + Text(Strings.inTodaysMoney)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            )
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var caption: some View {
        if report.isGoalReached {
            Text(Strings.amountOfGoal(Format.euro(report.snapshot.total), Format.euro(report.goal)))
                .font(Theme.caption)
                .foregroundStyle(.secondary)
        } else if let months {
            // The sentence itself moves with the slider rather than being replaced
            // by a "1.8 years sooner" line. Two reasons: the reader is already
            // looking here, so the horizon shrinking in place *is* the feedback;
            // and swapping one caption for another of a different height made the
            // whole popover twitch on every drag.
            projection(months: months)
                // A large goal makes this sentence long; wrapping is better than
                // truncating it mid-figure.
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                // Rolls the digits instead of cross-fading the line, so a drag
                // reads as one number counting down.
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy(duration: 0.25), value: months)
        } else {
            // Naming the rate would misdescribe this: with a dynamized plan the
            // contribution rises every year, so the remaining way to get here is
            // the 100-year horizon in `Projection.maxMonths`, not the rate alone.
            Text(Strings.notWithin100Years)
                .font(Theme.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// A slim progress bar toward the goal.
///
/// Replaces the ring the hero used to carry. The reasoning that shaped the ring
/// still applies, just in one dimension: a round-capped fill shorter than its own
/// height renders as a floating dot, and early in a long savings plan that is
/// exactly the case being drawn — so the fill has a floor wide enough to still
/// read as a bar that has started.
private struct ProgressBar: View {

    let progress: Double

    /// Animates from empty on appear, so opening the popover feels alive.
    @State private var shown: Double = 0

    private var height: CGFloat { 7 }

    var body: some View {
        GeometryReader { geometry in
            let full = geometry.size.width
            let fraction = min(max(shown, 0), 1)
            let width = progress > 0 ? max(fraction * full, height * 1.7) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.10))

                Capsule()
                    .fill(Theme.barGradient)
                    .frame(width: width)
                    .shadow(color: Theme.accent.opacity(0.35), radius: 3, y: 1)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) { shown = progress }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.snappy) { shown = new }
        }
    }
}
