import Foundation

/// A window the broker reports a trailing return over.
///
/// Raw values are the CLI's own `timeframe` strings, so decoding is a lookup and
/// an unrecognised window is skipped rather than crashing a payload that has
/// grown a new one.
public enum ReturnWindow: String, CaseIterable, Sendable {
    case intraday = "INTRADAY"
    case twoDays = "TWO_DAYS"
    case oneWeek = "ONE_WEEK"
    case oneMonth = "ONE_MONTH"
    case threeMonths = "THREE_MONTHS"
    case sixMonths = "SIX_MONTHS"
    case oneYear = "ONE_YEAR"
    case max = "MAX"

    /// Windows the popover offers, shortest first.
    ///
    /// Two are deliberately left out. `TWO_DAYS` is indistinguishable from
    /// `INTRADAY` whenever the market is shut — the live account returns the
    /// identical figure for both at a weekend — and "two days" is not a window
    /// anyone thinks in. `MAX` is not a window at all but the account's whole life,
    /// which belongs beside the balance rather than in a rotation of recent moves.
    public static let cyclable: [ReturnWindow] = [
        .intraday, .oneWeek, .oneMonth, .threeMonths, .sixMonths, .oneYear,
    ]

    /// How the window is named on screen.
    ///
    /// Naming it is not decoration. The sign genuinely differs between windows —
    /// the live account is up on the week and down on the month — so a bare arrow
    /// with no window attached would be picking whichever answer flattered.
    public var label: String {
        switch self {
        case .intraday: return Strings.windowToday
        case .twoDays: return Strings.windowTwoDays
        case .oneWeek: return Strings.windowThisWeek
        case .oneMonth: return Strings.windowThisMonth
        case .threeMonths: return Strings.windowThreeMonths
        case .sixMonths: return Strings.windowSixMonths
        case .oneYear: return Strings.windowPastYear
        case .max: return Strings.windowAllTime
        }
    }

    /// Whether the figure is only as fresh as the last trading session.
    ///
    /// True for the intraday window, and the reason it is not the default: markets
    /// are shut all weekend, so `INTRADAY` holds Friday's move for some sixty-four
    /// hours while a caption saying "today" quietly becomes false.
    public var isSessionBound: Bool { self == .intraday }

    /// The label, told whether the broker's valuation is from today.
    ///
    /// Only the session-bound window changes: "today" is a claim about the calendar
    /// that a Friday-evening valuation cannot support on a Sunday, and the honest
    /// version of the same figure is "last session". Every other window is a
    /// trailing span ending at the valuation, so its name stays true regardless.
    public func label(isCurrentSession: Bool) -> String {
        isSessionBound && !isCurrentSession ? Strings.windowLastSession : label
    }
}

/// Which way a window moved.
public enum MoveDirection: Equatable, Sendable {
    case up
    case down
    /// Rounds to nothing at the precision shown. Drawn as no arrow rather than a
    /// flat one: in the menu bar a "nothing happened" glyph is noise.
    case flat
}

/// A trailing return over one window, with the direction and percentage derived.
public struct MarketMove: Equatable {

    public let window: ReturnWindow

    /// Absolute return in EUR, signed.
    public let gain: Double

    /// `gain` over the value at the start of the window, or `nil` when that start
    /// value was zero or less and the ratio would be meaningless.
    public let fraction: Double?

    /// How the window is named here, which is not always `window.label` — the
    /// intraday one demotes itself to "last session" when the valuation is not from
    /// today. Resolved once at construction so the chip and the text output cannot
    /// name the same figure differently.
    public let windowLabel: String

    public init(window: ReturnWindow, gain: Double, total: Double, isCurrentSession: Bool = true) {
        self.window = window
        self.gain = gain
        self.windowLabel = window.label(isCurrentSession: isCurrentSession)
        // Derived rather than read, because the payload reports no percentage at
        // all: each performance entry carries an absolute return and nothing else.
        // Earlier CLI versions did carry a `performance` field intended for exactly
        // this, and returned `0` in it for every window — including ones with a
        // return of well over a thousand euros — which is why deriving started; sc
        // 0.6.0 dropped the field rather than fixing it, so there is still nothing
        // to read. Deriving needs the value the window *started* at, which is
        // today's total less what was made over it.
        let start = total - gain
        self.fraction = start > 0 ? gain / start : nil
    }

    /// Anything under half a cent rounds to `€0.00` on screen, and an arrow beside
    /// a zero is a claim the figure does not support.
    public var direction: MoveDirection {
        if abs(gain) < 0.005 { return .flat }
        return gain > 0 ? .up : .down
    }
}
