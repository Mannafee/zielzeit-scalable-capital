import Foundation

/// How far along the user is in connecting Zielzeit to their portfolio.
///
/// Since Scalable CLI 1.0 the gate is an account-level switch the user flips
/// themselves — Profile › Security › Agentic Investing on the Scalable web
/// platform — rather than a beta allowlisting request with a human at the other
/// end. The round-trip is gone, but the step is still invisible from here: only
/// the user knows whether they have flipped it.
public enum SetupState: Equatable {

    /// The CLI is not installed.
    case cliMissing

    /// The CLI is installed but there is no usable session.
    ///
    /// Whether that is because CLI access has not been enabled on the account
    /// yet or simply because nobody has logged in cannot be told apart from
    /// outside — both look identical until a login is attempted — so this state
    /// presents both steps and lets the user say which they have done.
    case notConnected(hasEnabledAccess: Bool)

    /// A session exists; the portfolio can be read.
    case connected(accountName: String?)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Everything needed to enable CLI access, install the CLI, and sign in.
///
/// Deliberately no automation of the login itself: the CLI's own guidance is to
/// complete login yourself rather than through another tool, and it uses an
/// OAuth device-code flow that wants a browser. Zielzeit hands the user the exact
/// command and gets out of the way.
public enum Onboarding {

    /// The CLI release this flow describes.
    ///
    /// Named because the steps below are version-specific: 1.0 retired
    /// `sc installation-code` and the beta allowlisting mailbox with it, so a
    /// user still on 0.6 would be told to flip a switch their CLI does not
    /// consult. Zielzeit does not run `sc --version` to find out — that would be
    /// a sixth command for a sentence — so the requirement is stated instead.
    public static let minimumCLIVersion = "1.0"

    /// Official install route. Zielzeit never ships its own copy of the CLI —
    /// the documentation asks users to trust only official artifacts, and a
    /// broker binary bundled inside a third-party app is exactly what that
    /// warning is about.
    public static let installCommand = "brew tap ScalableCapital/tap && brew install scalable-cli"

    /// Sign-in command. `--local-read-only` stores the session in locally
    /// enforced read-only mode, which matches what Zielzeit needs exactly and
    /// makes the read-only promise structural rather than editorial.
    public static let loginCommand = "sc login --local-read-only"

    public static let repositoryURL = URL(string: "https://github.com/ScalableCapital/scalable-cli")!

    /// Scalable Capital's own page for the switch that opens CLI access.
    ///
    /// Their published entry point, not a guessed deep link into the logged-in
    /// web app: a settings URL invented here would rot the first time they move
    /// the page, and it would send a signed-out user to a login wall with no
    /// explanation of what they came for.
    public static let accessURL = URL(string: "https://de.scalable.capital/en/agentic-investing")!

    /// Where the switch lives, as a breadcrumb.
    ///
    /// The labels stay English in every language, like the CLI's own commands:
    /// "Agentic Investing" is Scalable Capital's product name, and translating
    /// the path would send a user hunting for a menu item that does not exist
    /// under that name. The sentence around it is translated; the path is not.
    public static let accessPath = "Profile › Security › Agentic Investing"

    /// The one thing that leaves a user stuck with no error to search for.
    ///
    /// The switch is on the account, not on the machine, and it has to be on
    /// *before* `sc login` — a login attempted first fails with an
    /// authentication error that says nothing about a setting on a web page. So
    /// the ordering is called out wherever the step is offered.
    public static var orderNote: String { Strings.enableBeforeSigningIn }
}

/// Detects how far along setup is.
public protocol SetupProbing {
    func detectSetup() -> SetupState
}

/// Remembers the parts of setup that cannot be detected.
///
/// Whether the user has flipped the Agentic Investing switch on their account is
/// invisible from outside, so it is recorded here to stop the app repeating a
/// step already done.
public struct SetupStore {

    private enum Key {
        static let enabledAccess = "hasEnabledAccess"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? Defaults.shared()
    }

    public var hasEnabledAccess: Bool {
        get { defaults.bool(forKey: Key.enabledAccess) }
        nonmutating set { defaults.set(newValue, forKey: Key.enabledAccess) }
    }
}
