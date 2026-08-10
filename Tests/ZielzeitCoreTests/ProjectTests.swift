import XCTest
@testable import ZielzeitCore

/// The repository address, in the two forms that have to agree.
final class ProjectTests: XCTestCase {

    /// The film prints one and the footer menu opens the other. A rename that
    /// touched only one of them would send readers of the film to a dead address
    /// with nothing in the app able to reveal it, so the display form is pinned to
    /// the URL rather than merely living next to it.
    func testTheDisplayedAddressIsTheURLWithoutItsScheme() {
        XCTAssertEqual(Project.repositoryDisplay, "github.com/Mannafee/zielzeit-scalable-capital")
        XCTAssertEqual(
            Project.repositoryURL.absoluteString,
            "https://" + Project.repositoryDisplay
        )
    }
}
