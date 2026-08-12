import Foundation

// What the goal is worth in today's money, and how the portfolio has moved.

extension Report {

    // MARK: - Purchasing power

    /// The goal amount restated in today's money, at the projected horizon.
    ///
    /// Always shown rather than hidden behind a toggle, and not because inflation is
    /// a caveat — it is the difference between the goal meaning what the user thinks
    /// it means and not. Over the horizons this app quotes it is the largest single
    /// distortion in the number, larger than anything the disclaimer lists, and a
    /// caveat behind a disclosure triangle is one nobody reads.
    ///
    /// `nil` when there is no arrival to discount to, or when the horizon is so short
    /// that the restatement would be the same figure.
    public var realGoalValue: Double? {
        guard let months = headlineMonths, months >= 12 else { return nil }
        return Projection.realValue(nominal: goal, months: months)
    }

    // MARK: - Market movement

    /// The window the chip and the menu bar arrow open on.
    ///
    /// One week rather than intraday, which was the more obvious choice and the
    /// wrong one: `INTRADAY` is frozen from Friday's close until Monday's open, so
    /// the liveliest-looking window is the one that spends every weekend stale
    /// under a caption reading "today". A week always contains trading.
    public static let defaultWindow = ReturnWindow.oneWeek

    /// Whether the broker's valuation was struck today.
    ///
    /// `true` when the broker reported no timestamp at all: no evidence of staleness
    /// is not evidence of staleness, and the alternative is captioning perfectly
    /// fresh figures as belonging to a previous session.
    public var isValuationCurrent: Bool {
        guard let valued = snapshot.valuationDate else { return true }
        return calendar.isDate(valued, inSameDayAs: asOf)
    }

    /// The move over `window`, or `nil` when the broker did not report it.
    public func move(in window: ReturnWindow) -> MarketMove? {
        guard let gain = snapshot.returns[window] else { return nil }
        return MarketMove(
            window: window,
            gain: gain,
            total: snapshot.total,
            isCurrentSession: isValuationCurrent
        )
    }

    /// The windows worth offering: the cyclable ones this payload actually carries,
    /// shortest first.
    ///
    /// Filtered rather than assumed, so tapping never lands on a window with no
    /// figure behind it.
    public var availableWindows: [ReturnWindow] {
        ReturnWindow.cyclable.filter { snapshot.returns[$0] != nil }
    }

    /// Where the rotation starts: the default when it is available, otherwise the
    /// shortest window that is.
    public var initialWindow: ReturnWindow? {
        let available = availableWindows
        return available.contains(Self.defaultWindow) ? Self.defaultWindow : available.first
    }

    /// The next window in the rotation, wrapping at the end.
    ///
    /// Returns `window` itself when it is the only one available, so a tap on a
    /// single-window payload is a no-op rather than a jump to something absent.
    public func window(after window: ReturnWindow) -> ReturnWindow {
        let available = availableWindows
        guard let index = available.firstIndex(of: window), available.count > 1 else { return window }
        return available[(index + 1) % available.count]
    }

    /// The move shown when nothing has been chosen — and the only one the menu bar
    /// ever shows, since a status item has nothing to tap.
    public var defaultMove: MarketMove? {
        initialWindow.flatMap { move(in: $0) }
    }

    /// Every available move, for the text output.
    public var moves: [MarketMove] {
        availableWindows.compactMap { move(in: $0) }
    }
}
