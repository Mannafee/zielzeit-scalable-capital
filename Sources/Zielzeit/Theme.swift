import SwiftUI
import ZielzeitCore

/// The visual language: one place for colour, type, and metrics so the views
/// stay declarative and nothing drifts.
///
/// Colours are chosen to hold up in both light and dark appearance — the
/// popover is seen in both, and the accents are saturated enough to read
/// against either material.
enum Theme {

    // MARK: - Brand

    /// The brand palette, in `NSColor` because the app icon and the menu bar ring
    /// are drawn with AppKit while the popover is SwiftUI.
    ///
    /// One source of truth on purpose: these values previously existed three
    /// times over — here, in `AppIconArtwork` and in `StatusItemIcon` — and drifted
    /// apart, leaving the popover leading with blue while the icon was emerald.
    enum Brand {
        /// Highlight end of every gradient.
        static let mint = NSColor(srgbRed: 0.42, green: 0.95, blue: 0.83, alpha: 1)
        /// The primary accent.
        static let emerald = NSColor(srgbRed: 0.13, green: 0.76, blue: 0.53, alpha: 1)
        /// Shadow end of gradients, and the accent on light backgrounds.
        static let deep = NSColor(srgbRed: 0.02, green: 0.58, blue: 0.41, alpha: 1)
    }

    // MARK: - Colour

    /// Primary accent: the goal, progress, and the headline year.
    static let accent = Color(nsColor: Brand.emerald)
    /// Highlight end of gradients.
    static let accentAlt = Color(nsColor: Brand.mint)

    /// Per-scenario hues. Cautious reads as restrained, moderate as the steady
    /// benchmark, "your pace" as the warm measured outlier.
    static let cautious = Color(red: 0.45, green: 0.55, blue: 0.72)
    static let moderate = accent
    static let yourPace = Color(red: 0.98, green: 0.68, blue: 0.23)

    /// Market direction. Emerald and red rather than the scenario hues: this is
    /// gain-or-loss, the same question the "Past year" fact row already answers in
    /// those two colours.
    static func color(forDirection direction: MoveDirection) -> Color {
        switch direction {
        case .up: return accent
        case .down: return .red
        case .flat: return .secondary
        }
    }

    static func color(forScenario label: String) -> Color {
        switch label {
        case Report.cautiousLabel: return cautious
        case Report.moderateLabel: return moderate
        case Report.realizedLabel: return yourPace
        default: return .secondary
        }
    }

    /// Amber counterparts of the brand ramp, for when the headline is the
    /// realized pace and the hero has to match its curve rather than the brand.
    private enum Amber {
        static let bright = Color(red: 1.00, green: 0.81, blue: 0.38)
        static let base = Color(red: 0.98, green: 0.68, blue: 0.23)
        static let deep = Color(red: 0.78, green: 0.44, blue: 0.04)
    }

    /// Gradient for the big year, in the hue of whichever scenario the headline
    /// came from — otherwise the hero reads emerald while the curve it describes
    /// is amber.
    static func headlineGradient(forScenario label: String, _ scheme: ColorScheme) -> LinearGradient {
        guard label == Report.realizedLabel else { return accentGradient(scheme) }
        return LinearGradient(
            colors: scheme == .dark ? [Amber.bright, Amber.base] : [Amber.base, Amber.deep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Gradient for the headline year, matching the app icon's ring.
    ///
    /// Scheme-dependent because mint is bright enough to read beautifully on a
    /// dark popover and far too pale for 38pt text on a light one.
    static func accentGradient(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(nsColor: Brand.mint), Color(nsColor: Brand.emerald)]
                : [Color(nsColor: Brand.emerald), Color(nsColor: Brand.deep)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Sweep used by the progress ring, so the stroke shifts hue as it travels.
    ///
    /// Mint sits at the start: the arc grows from twelve o'clock, so early
    /// progress — the common case for years — shows the brightest part rather
    /// than a colour nobody sees until the goal is close.
    ///
    /// The angles stay at 0…360 even though the arc visually starts at twelve
    /// o'clock: the ring applies `rotationEffect(-90)`, which rotates the
    /// gradient along with the stroke. Pre-rotating here would offset mint from
    /// the arc's start by a quarter turn.
    static let ringGradient = AngularGradient(
        gradient: Gradient(colors: [
            Color(nsColor: Brand.mint),
            Color(nsColor: Brand.emerald),
            Color(nsColor: Brand.deep),
        ]),
        center: .center,
        startAngle: .degrees(0),
        endAngle: .degrees(360)
    )

    /// Left-to-right brand ramp for the progress bar. The bar measures progress
    /// toward the goal, so it stays emerald even when the headline is amber.
    static let barGradient = LinearGradient(
        colors: [Color(nsColor: Brand.mint), Color(nsColor: Brand.emerald)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// The mirror of `barGradient`, for a bar that measures a loss.
    ///
    /// Right-to-left so both ramps run outward from the axis they share: a
    /// left-growing bar with a left-to-right gradient would put its brightest end
    /// at the tip while its emerald twin puts it at the root.
    static let lossGradient = LinearGradient(
        colors: [Color(red: 0.86, green: 0.31, blue: 0.27), Color(red: 0.98, green: 0.51, blue: 0.44)],
        startPoint: .trailing,
        endPoint: .leading
    )

    /// Something is incomplete but nothing is wrong — an unfilled asset class, a
    /// scenario the portfolio trails its benchmark in.
    ///
    /// The same amber the realized-pace scenario uses, and deliberately so: this is
    /// the app's one "look at this" colour, and a second would compete with it.
    /// Kept distinct from `.red`, which is reserved for a loss.
    static let warning = yourPace

    /// Fill under the headline curve, tinted to that curve's own hue.
    static func areaGradient(forScenario label: String) -> LinearGradient {
        let hue = color(forScenario: label)
        return LinearGradient(
            colors: [hue.opacity(0.28), hue.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Type

    /// Large numerals. Rounded design reads as friendly rather than financial.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Small capitals used for section labels.
    ///
    /// Standard width on purpose: an expanded face on top of uppercase and
    /// letter-spacing stretches the glyphs and reads as distorted at this size.
    static let label = Font.system(size: 10, weight: .semibold)

    static let caption = Font.system(size: 11)
    static let body = Font.system(size: 12)

    // MARK: - Metrics

    static let popoverWidth: CGFloat = 344
    static let gutter: CGFloat = 16
    static let cornerRadius: CGFloat = 10
}

/// A small, lightly tracked all-caps section label.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label)
            .tracking(0.4)
            // Tertiary disappears against the popover's translucent material.
            .foregroundStyle(.secondary)
    }
}

/// Hairline divider that reads as a seam rather than a line.
struct Seam: View {
    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(height: 0.5)
            .opacity(0.6)
    }
}
