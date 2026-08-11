import SwiftUI
import ZielzeitCore

/// A stable shade per position, so the same fund is the same colour everywhere on
/// the holdings page.
///
/// One hue in five steps rather than five hues, and that is a constraint rather than
/// a preference: on this page amber already means "look at this" (the return outlier,
/// an unfilled asset class) and red already means a loss. Spending either on a fund's
/// identity would make a colour mean two things. What is left is the cool half of the
/// wheel, and five hues inside it do not separate — an indigo and a violet came out
/// at ΔE 9.8 for normal vision, which is below the threshold where anyone can tell
/// them apart, colourblind or not.
///
/// So identity is carried by lightness within the brand hue, with the legend naming
/// each fund once and a 2pt gap between neighbouring segments. That is a weaker
/// signal than five hues would be, and it is honest about what a 344pt popover can
/// actually distinguish.
enum HoldingPalette {

    /// Mint through deep emerald. Ordered light to dark; every step is checked for
    /// contrast against both the light and the dark popover.
    private static let dark: [Color] = [
        Color(red: 0.42, green: 0.95, blue: 0.83),
        Color(red: 0.27, green: 0.85, blue: 0.69),
        Color(red: 0.13, green: 0.76, blue: 0.53),
        Color(red: 0.08, green: 0.63, blue: 0.43),
        Color(red: 0.04, green: 0.48, blue: 0.34),
    ]

    /// The same ramp shifted darker, because mint on a white popover is a smear.
    private static let light: [Color] = [
        Color(red: 0.36, green: 0.83, blue: 0.68),
        Color(red: 0.18, green: 0.74, blue: 0.56),
        Color(red: 0.02, green: 0.58, blue: 0.41),
        Color(red: 0.02, green: 0.47, blue: 0.33),
        Color(red: 0.01, green: 0.38, blue: 0.26),
    ]

    /// The shade for a position, by its size in the portfolio.
    ///
    /// Largest takes the lightest step, so the composition bar runs light to dark from
    /// left to right and reads as one designed mark rather than five arbitrary greens.
    /// Keyed to valuation and not to the ISIN, which is a deliberate trade: a fund's
    /// shade changes if two positions swap places, but a buy-and-hold portfolio
    /// reorders rarely, the legend names every fund beside its chip, and the
    /// alternative — stable shades in scrambled order — made the one mark this page is
    /// built around look like an accident.
    ///
    /// It also earns something in the sections below, where rows are ordered by
    /// contribution rather than by size: a light bar sitting low means a large holding
    /// that is pulling less than its weight.
    ///
    /// Wraps past the end of the ramp. A portfolio of more than five funds gets
    /// repeated shades, which the legend disambiguates; inventing further steps would
    /// produce pairs too close to tell apart.
    static func shade(for holding: Holding, in holdings: HoldingsSnapshot, dark: Bool) -> Color {
        let ramp = dark ? Self.dark : Self.light
        let index = holdings.byValuation.firstIndex(of: holding) ?? 0
        return ramp[index % ramp.count]
    }
}

extension View {

    /// Resolves the palette against the current appearance.
    ///
    /// A helper rather than each call site reading the environment, so no view can
    /// pick the dark ramp on a light popover.
    func holdingShade(
        _ holding: Holding,
        in holdings: HoldingsSnapshot,
        scheme: ColorScheme
    ) -> Color {
        HoldingPalette.shade(for: holding, in: holdings, dark: scheme == .dark)
    }
}
