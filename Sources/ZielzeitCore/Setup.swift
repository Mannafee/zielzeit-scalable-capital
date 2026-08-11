import Foundation

/// How far along the user is in connecting Zielzeit to their portfolio.
///
/// The Scalable CLI is in beta and gated: a client must be allowlisted by
/// Scalable Capital before it can log in at all. That means onboarding has a
/// human round-trip in the middle which no amount of software can remove — so
/// the app's job is to make every step around it a single tap, and to be honest
/// about the one step that has to wait on someone else.
public enum SetupState: Equatable {

    /// The CLI is not installed.
    case cliMissing

    /// The CLI is installed but there is no usable session.
    ///
    /// Whether that is because the installation has not been allowlisted yet or
    /// simply because nobody has logged in cannot be told apart from outside —
    /// both look identical until a login is attempted — so this state presents
    /// both steps and lets the user say which they have done.
    case notConnected(installationCode: String?, hasRequestedAccess: Bool)

    /// A session exists; the portfolio can be read.
    case connected(accountName: String?)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Everything needed to ask Scalable Capital for access, and to install and sign
/// in to the CLI.
///
/// Deliberately no automation of the login itself: the CLI's own guidance is to
/// complete login yourself rather than through another tool, and it uses an
/// OAuth device-code flow that wants a browser. Zielzeit hands the user the exact
/// command and gets out of the way.
public enum AccessRequest {

    /// Beta allowlisting address, from the CLI's documentation.
    public static let emailAddress = "cli.beta@scalable.capital"

    /// Subject line the documentation asks for.
    public static let emailSubject = "Scalable CLI Allowlisting"

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

    /// The one thing that silently sinks a request.
    ///
    /// Scalable Capital matches the allowlisting request to an account by sender
    /// address. A `mailto:` link opens whatever the default mail account is,
    /// which is often not the address the brokerage account uses — and a request
    /// from an unrecognised sender simply never gets answered, with nothing in
    /// the app able to reveal why. So the sender has to be called out explicitly
    /// wherever the request is offered.
    public static var senderNote: String { Strings.senderNote }

    /// Body of the allowlisting request.
    ///
    /// Deliberately English in every language. This is not app copy: it goes to
    /// Scalable Capital's beta address, where the documented process is in
    /// English and a request that reads unexpectedly is a request that waits
    /// longer. The app's own warning around it is translated; the message itself
    /// is not.
    public static func emailBody(installationCode: String) -> String {
        """
        Hello,

        I'd like to request allowlisting for the Scalable CLI beta.

        Installation code: \(installationCode)

        Thank you.
        """
    }

    /// A `mailto:` URL that opens the user's mail client fully prefilled.
    ///
    /// This is the point of the whole flow: instead of reading a README, running
    /// a command, copying a code and composing the message correctly, the user
    /// taps once and sends.
    public static func mailtoURL(installationCode: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = emailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: emailSubject),
            URLQueryItem(name: "body", value: emailBody(installationCode: installationCode)),
        ]
        // `mailto` bodies must encode "+" or mail clients read it as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }
}

/// Detects how far along setup is.
public protocol SetupProbing {
    func detectSetup() -> SetupState
}

/// Remembers the parts of setup that cannot be detected.
///
/// Whether the user has already emailed for allowlisting is invisible from
/// outside, so it is recorded here to stop the app nagging about a step already
/// done.
public struct SetupStore {

    private enum Key {
        static let requestedAccess = "hasRequestedAccess"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? Defaults.shared()
    }

    public var hasRequestedAccess: Bool {
        get { defaults.bool(forKey: Key.requestedAccess) }
        nonmutating set { defaults.set(newValue, forKey: Key.requestedAccess) }
    }
}
