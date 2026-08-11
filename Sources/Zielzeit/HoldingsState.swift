import Foundation
import ZielzeitCore

/// What the holdings page is currently showing.
///
/// Its own state rather than a case on `ViewState`: the page is a second screen
/// over a working popover, so it must be able to fail on its own without taking
/// the projection behind it down. Closing it and reopening leaves the last good
/// page in place — the two calls behind it are not cheap.
enum HoldingsState {

    /// Never opened, or opened and its data since discarded.
    case idle
    case loading
    case ready(HoldingsReport)
    /// The page could not be read; carries the reason.
    case failure(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var report: HoldingsReport? {
        guard case .ready(let report) = self else { return nil }
        return report
    }

    /// Whether opening the page would have to fetch.
    var needsFetch: Bool {
        switch self {
        case .idle, .failure: return true
        case .loading, .ready: return false
        }
    }
}
