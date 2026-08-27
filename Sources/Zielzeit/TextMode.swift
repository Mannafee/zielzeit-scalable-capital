import Foundation
import ZielzeitCore

/// `zielzeit --once`: print the report to stdout and exit.
///
/// Exists so the whole pipeline — CLI call, decoding, projection, formatting —
/// can be exercised from a terminal without a menu bar.
enum TextMode {

    /// Returns a process exit code.
    static func run(
        provider: PortfolioProviding = ScalableClient(),
        goalStore: GoalStore = GoalStore(),
        prober: SetupProbing? = ScalableClient()
    ) -> Int32 {
        // Same guidance the popover gives, so a terminal user is not left with a
        // bare error when the real problem is that setup is incomplete.
        if let prober {
            let setup = prober.detectSetup()
            if !setup.isConnected {
                complain(setupInstructions(for: setup))
                return 3
            }
        }

        guard let goal = goalStore.goal else {
            complain(Strings.noGoalSet)
            return 2
        }
        do {
            let snapshot = try provider.fetchSnapshot()
            print(Report(goal: goal, snapshot: snapshot).textReport())
            return 0
        } catch {
            complain(Strings.errorPrefix(error.localizedDescription))
            return 1
        }
    }

    /// The onboarding steps, as text.
    private static func setupInstructions(for state: SetupState) -> String {
        var lines = [Strings.notConnectedYet, ""]

        switch state {
        case .cliMissing:
            lines += [
                Strings.stepInstallCLI,
                "     \(Onboarding.installCommand)",
                "   \(Strings.cliVersionRequirement(Onboarding.minimumCLIVersion))  \(Onboarding.repositoryURL.absoluteString)",
                "",
                Strings.stepEnableAccess,
                "     \(Onboarding.accessPath)",
                "   \(Onboarding.accessURL.absoluteString)",
                "   \(Onboarding.orderNote)",
                "",
                Strings.stepSignIn,
                "     \(Onboarding.loginCommand)",
            ]

        case .notConnected(let hasEnabled):
            if !hasEnabled {
                lines += [
                    Strings.ifNotEnabledYet,
                    "  \(Onboarding.accessPath)",
                    "  \(Onboarding.accessURL.absoluteString)",
                    "  \(Onboarding.orderNote)",
                    "",
                ]
            }
            lines += [Strings.thenSignIn, "  \(Onboarding.loginCommand)"]

        case .connected:
            break
        }

        return lines.joined(separator: "\n")
    }

    private static func complain(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
