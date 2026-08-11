import Foundation
import ZielzeitCore

/// What the menu bar is currently showing.
enum ViewState {
    /// The CLI is not installed, or there is no session yet.
    case setup(SetupState)
    /// Connected, but no target amount configured yet.
    case noGoal
    /// A fetch is in flight and there is nothing cached to show.
    case loading
    /// Live data.
    case ready(Report)
    /// Connected, but the portfolio could not be read; carries the reason.
    case failure(String)

    /// Text shown beside the menu bar icon. Empty means icon only.
    var menuBarText: String {
        switch self {
        case .setup: return Strings.menuBarSetUp
        case .noGoal: return Strings.menuBarSetGoal
        case .loading: return "…"
        case .ready(let report): return report.menuBarText
        case .failure: return ""
        }
    }

    /// Which way the market moved, for the caret beside the ring.
    ///
    /// Always the report's default window: the status item has nothing to tap, so
    /// unlike the popover chip it cannot let the reader choose. `nil` in every state
    /// but `.ready` — a caret over stale or absent data would be a claim about right
    /// now.
    var menuBarDirection: MoveDirection? {
        guard case .ready(let report) = self else { return nil }
        return report.defaultMove?.direction
    }

    /// The report on screen, when there is one.
    ///
    /// The holdings page needs the projection to measure its weeks against, and it
    /// can only be opened from `.ready` — so this is how it asks, rather than by
    /// re-deriving a report of its own.
    var report: Report? {
        guard case .ready(let report) = self else { return nil }
        return report
    }

    /// Progress for the ring icon, or `nil` when a symbol should be shown instead.
    ///
    /// Once connected the icon is always a ring — an empty one before a goal is
    /// set — so the menu bar reads consistently. Only the unconnected and error
    /// states swap in a symbol.
    var iconProgress: Double? {
        switch self {
        case .ready(let report): return report.progress
        case .loading, .noGoal: return 0
        case .setup, .failure: return nil
        }
    }
}
