import XCTest
@testable import ZielzeitCore

/// The onboarding steps have to be exactly right — a wrong command or a wrong
/// place to look means the user gets an authentication error that points
/// nowhere, and nothing in the app would reveal why.
final class OnboardingTests: XCTestCase {

    func testInstallCommandUsesTheOfficialTap() {
        // Zielzeit never ships its own copy of the CLI: the documentation asks
        // users to trust only official artifacts.
        XCTAssertTrue(Onboarding.installCommand.contains("ScalableCapital/tap"))
        XCTAssertTrue(Onboarding.installCommand.contains("scalable-cli"))
    }

    func testLoginCommandEnforcesReadOnly() {
        // The whole product promise is read-only access; the session should be
        // structurally incapable of mutation.
        XCTAssertEqual(Onboarding.loginCommand, "sc login --local-read-only")
    }

    func testTheFlowDescribesTheOneOhCLI() {
        // The steps are version-specific: 1.0 retired `sc installation-code` and
        // the beta mailbox, and replaced both with an account switch.
        XCTAssertEqual(Onboarding.minimumCLIVersion, "1.0")
    }

    func testAccessURLIsScalableCapitalOverTLS() throws {
        let url = Onboarding.accessURL
        XCTAssertEqual(url.scheme, "https")
        let host = try XCTUnwrap(url.host)
        XCTAssertTrue(host.hasSuffix("scalable.capital"), host)
    }

    func testAccessPathNamesTheSettingAsScalableDoes() {
        // Kept in Scalable Capital's words on purpose: a translated breadcrumb
        // sends the user hunting for a menu item that does not exist.
        let path = Onboarding.accessPath
        XCTAssertTrue(path.contains("Security"), path)
        XCTAssertTrue(path.contains("Agentic Investing"), path)
    }
}

/// The ordering requirement is the one mistake that fails with an error pointing
/// somewhere else, so the warning has to actually say what to do and when.
final class OrderNoteTests: XCTestCase {

    func testOrderNoteNamesSigningInAsTheThingItComesBefore() {
        let note = Onboarding.orderNote
        XCTAssertTrue(note.lowercased().contains("sign in"), note)
        XCTAssertTrue(note.lowercased().contains("before"), note)
    }
}

final class SetupStateTests: XCTestCase {

    func testOnlyConnectedCountsAsConnected() {
        XCTAssertTrue(SetupState.connected(accountName: "Ada").isConnected)
        XCTAssertTrue(SetupState.connected(accountName: nil).isConnected)
        XCTAssertFalse(SetupState.cliMissing.isConnected)
        XCTAssertFalse(SetupState.notConnected(hasEnabledAccess: true).isConnected)
    }
}

final class SetupStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "com.zielzeit.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testEnabledAccessDefaultsToFalseAndPersists() {
        let store = SetupStore(defaults: defaults)
        XCTAssertFalse(store.hasEnabledAccess)
        store.hasEnabledAccess = true
        XCTAssertTrue(SetupStore(defaults: defaults).hasEnabledAccess)
    }
}

/// Setup detection against a stub CLI, so every branch is exercised without
/// touching the real one.
final class SetupProbeTests: XCTestCase {

    func testMissingCLIIsDetectedWithoutRunningAnything() {
        let client = ScalableClient(executablePath: "/nonexistent/sc")
        XCTAssertEqual(client.detectSetup(), .cliMissing)
    }

    func testFailingSessionReportsNotConnected() throws {
        let script = try makeScript("#!/bin/sh\necho 'no saved session, please run sc login' >&2\nexit 1\n")
        defer { try? FileManager.default.removeItem(at: script) }

        let state = ScalableClient(executablePath: script.path, timeout: 5).detectSetup()
        guard case .notConnected = state else {
            return XCTFail("expected notConnected, got \(state)")
        }
    }

    func testWorkingSessionReportsConnectedWithTheAccountName() throws {
        let script = try makeScript("""
        #!/bin/sh
        echo '{"ok":true,"command":"whoami","data":{"result":{"personOverview":{"personalDetails":{"firstName":"Ada"}}}}}'
        """)
        defer { try? FileManager.default.removeItem(at: script) }

        let state = ScalableClient(executablePath: script.path, timeout: 5).detectSetup()
        XCTAssertEqual(state, .connected(accountName: "Ada"))
    }

    func testSessionWithoutANameStillCountsAsConnected() throws {
        let script = try makeScript("""
        #!/bin/sh
        echo '{"ok":true,"command":"whoami","data":{"result":{}}}'
        """)
        defer { try? FileManager.default.removeItem(at: script) }

        XCTAssertEqual(
            ScalableClient(executablePath: script.path, timeout: 5).detectSetup(),
            .connected(accountName: nil)
        )
    }

    /// The state a real new user is in: CLI installed, no session yet.
    ///
    /// What is pinned here is what the probe *does not* do. Until Scalable CLI
    /// 1.0 this branch went on to run `sc installation-code` for the code the
    /// old Request-access button emailed; the command is retired, the button is
    /// gone, and a probe that still reached for a second command would fail
    /// slowly against a CLI that no longer answers it.
    func testUnauthenticatedProbeRunsWhoamiAndNothingElse() throws {
        let log = FileManager.default.temporaryDirectory
            .appendingPathComponent("zielzeit-probe-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: log) }

        let script = try makeScript("""
        #!/bin/sh
        echo "$1" >> "\(log.path)"
        echo 'no saved session, please run sc login' >&2
        exit 1
        """)
        defer { try? FileManager.default.removeItem(at: script) }

        let state = ScalableClient(executablePath: script.path, timeout: 5).detectSetup()
        guard case .notConnected = state else {
            return XCTFail("expected notConnected, got \(state)")
        }

        let invoked = try String(contentsOf: log, encoding: .utf8)
            .split(separator: "\n").map(String.init)
        XCTAssertEqual(invoked, ["whoami"], "the probe ran more than `sc whoami`")
    }

    // MARK: - Helpers

    private func makeScript(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zielzeit-setup-\(UUID().uuidString).sh")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }
}
