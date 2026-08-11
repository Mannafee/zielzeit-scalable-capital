import Foundation
import ZielzeitCore

/// The pages the popover can be swiped between, in the order they sit side by side.
///
/// Two of them, and the order is the reading order: the projection is what the app
/// is for and stays the page the popover opens on, with the positions behind it as
/// the detail you go looking for.
enum PopoverPage: Int, CaseIterable, Identifiable, Hashable {

    case projection
    case holdings

    var id: Int { rawValue }

    /// How the page is named to a screen reader and on its dot's tooltip. Neither
    /// page shows this as a heading — the projection has no title bar and the
    /// holdings page carries its own.
    var label: String {
        switch self {
        case .projection: return Strings.projectionsHeading
        case .holdings: return Strings.holdings
        }
    }
}
