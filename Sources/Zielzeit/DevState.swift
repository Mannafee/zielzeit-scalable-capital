import Foundation
import ZielzeitCore

/// Builds a model in a named state, so `--render` and `--open` can both show any
/// state on demand instead of only whatever the live data happens to produce.
///
/// Development-only: the shipping app always starts from real data.
@MainActor
enum DevState {

    /// Why a state could not be built (a missing goal, an unreadable CLI).
    struct Failure: Error {
        let message: String
    }

    static let names = ["ready", "slider", "target-year", "caveats", "market-down", "holdings",
                        "no-goal", "loading", "failure", "editing", "setup-cli", "setup-access",
                        "setup-requested"]

    /// Returns the model, or an error message to print.
    static func model(
        named name: String,
        provider: PortfolioProviding = ScalableClient(),
        goalStore: GoalStore = GoalStore()
    ) -> Result<AppModel, Failure> {
        let outcome = build(name: name, provider: provider, goalStore: goalStore)
        // Every dev state is pinned: opening the popover triggers a refresh,
        // which would otherwise replace the state being previewed with live data.
        if case .success(let model) = outcome { model.isPinned = true }
        return outcome
    }

    private static func build(
        name: String,
        provider: PortfolioProviding,
        goalStore: GoalStore
    ) -> Result<AppModel, Failure> {
        switch name {
        case "no-goal":
            return .success(AppModel(provider: provider, goalStore: goalStore, state: .noGoal))

        case "setup-cli":
            return .success(AppModel(
                provider: provider, goalStore: goalStore, state: .setup(.cliMissing)
            ))

        case "setup-access":
            return .success(AppModel(
                provider: provider, goalStore: goalStore,
                state: .setup(.notConnected(installationCode: "DEMO-1234-5678-ABCD", hasRequestedAccess: false))
            ))

        case "setup-requested":
            return .success(AppModel(
                provider: provider, goalStore: goalStore,
                state: .setup(.notConnected(installationCode: "DEMO-1234-5678-ABCD", hasRequestedAccess: true))
            ))

        case "loading":
            return .success(AppModel(provider: provider, goalStore: goalStore, state: .loading))

        case "failure":
            return .success(AppModel(
                provider: provider,
                goalStore: goalStore,
                state: .failure("Not logged in — run `sc login` in a terminal")
            ))

        case "editing":
            let model = AppModel(provider: provider, goalStore: goalStore, state: .noGoal)
            model.beginEditingGoal()
            return .success(model)

        case "ready", "slider", "target-year", "caveats", "market-down", "holdings":
            guard let goal = goalStore.goal else {
                return .failure(Failure(message: "No goal set; pass ZIELZEIT_GOAL."))
            }
            do {
                let snapshot = try provider.fetchSnapshot()
                let report = Report(goal: goal, snapshot: snapshot)
                let model = AppModel(
                    provider: provider,
                    goalStore: goalStore,
                    state: .ready(report)
                )
                model.lastFetch = Date()
                // Park the slider mid-range so the what-if affordance is visibly
                // doing something.
                if name == "slider" { model.extraSavings = 200 }
                // Drag the "reach by" slider two years earlier than projected, so
                // the state shows a demand well above what is saved now rather
                // than the near-identical figure the default position gives.
                if name == "target-year", let projected = report.headlineYear {
                    model.chosenTargetYear = Double(projected - 2)
                }
                if name == "caveats" { model.showsCaveats = true }
                // The chip's default window is whatever the market did, so the
                // losing colour is not reviewable on demand without pinning a
                // window that is down. Falls back to the longest available rather
                // than guessing, since which windows are negative changes daily.
                if name == "market-down" {
                    model.marketWindow = report.availableWindows
                        .first { (report.move(in: $0)?.direction ?? .flat) == .down }
                        ?? report.availableWindows.last
                }
                // The holdings page is fetched here rather than through
                // `showHoldings()`, which is asynchronous: `--render` screenshots
                // the popover as soon as it has a model, and would catch the
                // spinner instead of the page. Every dev state is pinned, so
                // nothing later overwrites what this puts in place.
                if name == "holdings" {
                    model.page = .holdings
                    model.holdings = holdingsState(for: report, provider: provider)
                }
                return .success(model)
            } catch {
                return .failure(Failure(message: "Error: \(error.localizedDescription)"))
            }

        default:
            return .failure(Failure(message: "Unknown state \(name.debugDescription). Try: \(names.joined(separator: ", "))"))
        }
    }

    /// Reads the holdings page synchronously, for `--render` and `--open`.
    ///
    /// Falls back to a failure state carrying the reason rather than to no page at
    /// all: `--open holdings` against a demo CLI that has not implemented the two
    /// commands should say so on screen, which is the same thing a real account
    /// with an old CLI would see.
    private static func holdingsState(
        for report: Report,
        provider: PortfolioProviding
    ) -> HoldingsState {
        // Reuses whichever binary the model is already reading, so `sc-demo` serves
        // this page exactly as it serves the projection behind it.
        guard let source = provider as? HoldingsProviding else {
            return .failure("This provider does not read holdings.")
        }
        do {
            return .ready(HoldingsReport(holdings: try source.fetchHoldings(), report: report))
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
