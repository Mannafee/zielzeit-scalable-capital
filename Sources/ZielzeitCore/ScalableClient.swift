import Foundation

public enum ScalableError: LocalizedError, Equatable {
    case notInstalled(path: String)
    case timedOut
    case notLoggedIn
    case failed(String)
    case unexpectedResponse(command: String)

    public var errorDescription: String? {
        switch self {
        case .notInstalled(let path):
            return Strings.cliNotFound(path: path)
        case .timedOut:
            return Strings.cliTimedOut
        case .notLoggedIn:
            return Strings.notLoggedIn
        // The CLI's own message, passed through untranslated: it is the broker
        // speaking, not Zielzeit, and paraphrasing it would make a real error
        // harder to search for.
        case .failed(let message):
            return message
        case .unexpectedResponse(let command):
            return Strings.unexpectedResponse(command: command)
        }
    }
}

/// Reads portfolio data from the official Scalable CLI.
///
/// Strictly read-only: the only commands this type can run are the six listed
/// in `Command`. There is no code path to a trade or any other write command,
/// and none to `login` either — that is the user's to run.
public struct ScalableClient: PortfolioProviding, HoldingsProviding, SetupProbing {

    /// The read-only commands Zielzeit uses. Exhaustive by design.
    ///
    /// `installationCode` generates a local proof code and needs no session;
    /// `whoami` is the cheapest way to tell whether a session works. Neither
    /// mutates anything, and there is deliberately no `login` here — the CLI's
    /// guidance is that the user completes login themselves.
    enum Command {
        static let overview = ["broker", "overview"]
        static let savingsPlans = ["broker", "savings-plans"]
        static let installationCode = ["installation-code"]
        static let whoami = ["whoami"]

        /// Per-position detail: the whole of the holdings page.
        ///
        /// The sixth member, and the only one the page needs. `broker analytics` was
        /// here too for a while, for a diversification panel and the broker's stress
        /// scenarios; both were cut because neither answered the question this app
        /// asks, so the command they required went with them.
        ///
        /// Read-only like the rest: there is no flag on it that writes.
        static let holdings = ["broker", "holdings"]

        /// Cash flow history, used to measure what actually went in over the past
        /// year instead of inferring it from the current plan rate. Read-only, and
        /// the filters are ours: page size is the CLI's maximum, and `--from-time`
        /// bounds the walk to the window Dietz needs.
        static func transactions(since: Date, cursor: String? = nil) -> [String] {
            var arguments = [
                "broker", "transactions",
                "--page-size", String(transactionPageSize),
                "--from-time", iso8601.string(from: since),
            ]
            if let cursor { arguments += ["--cursor", cursor] }
            return arguments
        }

        /// The CLI's documented maximum (1..100).
        static let transactionPageSize = 100

        private static let iso8601: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter
        }()
    }

    /// Stops the paging loop from following a broken cursor forever. Ten pages is
    /// a thousand transactions in a year — far beyond a savings plan plus manual
    /// buying, and the sum is only an input to a rate estimate.
    static let maximumTransactionPages = 10

    /// The CLI is invoked by absolute path on purpose. An app launched from
    /// Finder or by launchd inherits a minimal `PATH` that excludes
    /// `/opt/homebrew/bin`, so a bare `sc` would work when run from a shell and
    /// fail mysteriously in the built app.
    public static let defaultExecutablePath = "/opt/homebrew/bin/sc"

    private let executablePath: String
    private let timeout: TimeInterval

    public init(executablePath: String? = nil, timeout: TimeInterval = 20) {
        self.executablePath = executablePath
            ?? ProcessInfo.processInfo.environment["ZIELZEIT_SC_BIN"]
            ?? Self.defaultExecutablePath
        self.timeout = timeout
    }

    // MARK: - PortfolioProviding

    public func fetchSnapshot() throws -> PortfolioSnapshot {
        let overview = try run(OverviewResult.self, arguments: Command.overview)
        let plans = try run(SavingsPlansResult.self, arguments: Command.savingsPlans)

        return PortfolioSnapshot(
            total: overview.valuation.total,
            monthlySavings: plans.totalSavingsPlanAmount ?? 0,
            savingsPlanCount: plans.count ?? 0,
            dynamizationRate: plans.dynamizationRate,
            // Deliberately non-fatal, and non-throwing for that reason: this is a
            // refinement to a rate estimate, so an older CLI without the command, or
            // a transaction list that will not decode, degrades to the
            // `12 × monthly` estimate rather than taking the whole portfolio read
            // down with it. Failures are turned into `nil` inside the call.
            trailingContributions: trailingContributions(),
            returns: overview.trailingReturns,
            valuationDate: overview.valuationDate
        )
    }

    // MARK: - HoldingsProviding

    /// Every position the portfolio holds.
    ///
    /// Throwing rather than degrading, unlike `trailingContributions`: this is the
    /// entire content of the holdings page, so there is nothing to show if it
    /// fails, and a page that silently rendered an empty portfolio would read as
    /// "you own nothing" rather than as "this could not be read".
    public func fetchHoldings() throws -> HoldingsSnapshot {
        let result = try run(HoldingsResult.self, arguments: Command.holdings)
        return HoldingsSnapshot(items: result.holdings)
    }

    /// Net external money over the trailing year: deposits less withdrawals.
    ///
    /// Cash flows only. Security movements are excluded on purpose — a custody
    /// migration shows up as a matched pair of `NON_TRADE_SECURITY_TRANSACTION`
    /// entries (out one day, in the next, same ISINs, same amounts) and counting
    /// those as contributions would wreck the rate. Interest is excluded too: it is
    /// a return the portfolio earned, not money the user put in.
    ///
    /// Known gap: securities *transferred in* from another broker are a real
    /// contribution that no cash flow records, so they still read as performance.
    /// Nothing in this payload distinguishes them from a migration.
    public func trailingContributions(now: Date = Date(), calendar: Calendar = .current) -> Double? {
        guard let from = calendar.date(byAdding: .year, value: -1, to: now) else { return nil }

        var net = 0.0
        var cursor: String?
        var pages = 0

        repeat {
            let page: TransactionsResult
            do {
                page = try run(
                    TransactionsResult.self,
                    arguments: Command.transactions(since: from, cursor: cursor)
                )
            } catch {
                // A failure part-way through would otherwise report a partial year
                // as if it were the whole one, which is worse than not measuring.
                return nil
            }
            net += page.netExternalFlow
            cursor = page.nextCursor
            pages += 1
        } while cursor != nil && pages < Self.maximumTransactionPages

        // A cursor still outstanding means the window was not fully walked.
        guard cursor == nil else { return nil }
        return net
    }

    // MARK: - Setup

    /// Whether the CLI is present and executable.
    public var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: executablePath)
    }

    /// Works out how far along setup is, without ever attempting a login.
    ///
    /// Note what this deliberately cannot determine: whether a failing session is
    /// due to missing allowlisting or simply not having logged in. Both surface
    /// identically, and finding out would mean starting a login on the user's
    /// behalf. So it reports `notConnected` and lets the UI present both steps.
    public func detectSetup() -> SetupState {
        guard isInstalled else { return .cliMissing }

        do {
            // A working session with no name attached still counts as connected.
            return .connected(accountName: try signedInName())
        } catch {
            return .notConnected(
                installationCode: try? installationCode(),
                hasRequestedAccess: SetupStore().hasRequestedAccess
            )
        }
    }

    /// The installation code Scalable Capital needs in order to allowlist this
    /// machine. Requires no session.
    public func installationCode() throws -> String {
        let data = try execute(arguments: Command.installationCode + ["--json"])
        // Unlike the broker commands, this payload sits directly under `data`
        // rather than `data.result`.
        let envelope = try Self.decodeDirect(
            InstallationCodePayload.self, from: data, command: "installation-code"
        )
        return envelope.displayCode ?? envelope.installationCode
    }

    /// The signed-in person's first name, or `nil` if the session works but the
    /// name is not present. Throws when there is no usable session.
    public func signedInName() throws -> String? {
        let result = try run(WhoAmIResult.self, arguments: Command.whoami)
        return result.personOverview?.personalDetails?.firstName
    }

    // MARK: - Decoding

    private func run<T: Decodable>(_ type: T.Type, arguments: [String]) throws -> T {
        let label = arguments.joined(separator: " ")
        let data = try execute(arguments: arguments + ["--json"])
        return try Self.decode(T.self, from: data, command: label)
    }

    /// Split out from process handling so the wire format can be tested against
    /// captured fixtures.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data, command: String) throws -> T {
        let envelope: Envelope<T>
        do {
            envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        } catch {
            // An installed CLI with no session prints plain text, not JSON.
            if Self.looksLikeAuthProblem(data) { throw ScalableError.notLoggedIn }
            throw ScalableError.unexpectedResponse(command: command)
        }
        guard envelope.ok else {
            throw ScalableError.failed(envelope.error ?? "`sc \(command)` reported a failure")
        }
        guard let result = envelope.data?.result else {
            throw ScalableError.unexpectedResponse(command: command)
        }
        return result
    }

    /// Decodes `{ok, data: T}` — the shape used by commands whose payload is not
    /// wrapped in a `result` object.
    static func decodeDirect<T: Decodable>(_ type: T.Type, from data: Data, command: String) throws -> T {
        let envelope: DirectEnvelope<T>
        do {
            envelope = try JSONDecoder().decode(DirectEnvelope<T>.self, from: data)
        } catch {
            if Self.looksLikeAuthProblem(data) { throw ScalableError.notLoggedIn }
            throw ScalableError.unexpectedResponse(command: command)
        }
        guard envelope.ok else {
            throw ScalableError.failed(envelope.error ?? "`sc \(command)` reported a failure")
        }
        guard let payload = envelope.data else {
            throw ScalableError.unexpectedResponse(command: command)
        }
        return payload
    }

    private static func looksLikeAuthProblem(_ data: Data) -> Bool {
        let text = String(decoding: data, as: UTF8.self).lowercased()
        return ["login", "session", "unauthor", "expired"].contains { text.contains($0) }
    }

    // MARK: - Process handling

    private func execute(arguments: [String]) throws -> Data {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw ScalableError.notInstalled(path: executablePath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ScalableError.notInstalled(path: executablePath)
        }

        // Drain stdout concurrently with waiting: a full pipe buffer would
        // otherwise block the child forever.
        let output = Box<Data>(Data())
        let draining = DispatchGroup()
        draining.enter()
        DispatchQueue.global(qos: .utility).async {
            output.value = stdout.fileHandleForReading.readDataToEndOfFile()
            draining.leave()
        }

        // The CLI does network I/O, so an unbounded wait here would hang the
        // menu bar. Terminate rather than wait forever.
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            usleep(50_000)
        }
        if process.isRunning {
            process.terminate()
            throw ScalableError.timedOut
        }
        process.waitUntilExit()
        _ = draining.wait(timeout: .now() + 5)

        let data = output.value
        guard !data.isEmpty else { throw try failure(from: stderr) }
        return data
    }

    private func failure(from stderr: Pipe) throws -> ScalableError {
        let text = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().contains("login") { return .notLoggedIn }
        return .failed(text.isEmpty ? "`sc` produced no output" : text)
    }
}

/// Minimal reference box so a value can be written from the draining queue and
/// read back after the `DispatchGroup` barrier.
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
