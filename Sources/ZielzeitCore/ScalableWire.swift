import Foundation

// The shape of what the `sc` CLI prints, kept apart from ScalableClient so that
// running the CLI and decoding it stay separate concerns: these types change
// when the CLI's output changes, the client when our own behaviour does.

/// Kept for the tests that assert the one-year entry is picked by `timeframe`
/// rather than by position. `ReturnWindow`'s raw values are the same strings and
/// are what production reads.
enum Timeframe {
    static let oneYear = ReturnWindow.oneYear.rawValue
}

/// Parses the CLI's ISO 8601 timestamps.
///
/// Kept lenient and non-throwing on purpose: every timestamp in this app is a
/// refinement to a label, never a figure, so an unexpected shape must cost the
/// label rather than the read it arrived with.
enum WireTimestamp {

    static func parse(_ text: String) -> Date? {
        for formatter in [fractionalSeconds, wholeSeconds] {
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// The shape the CLI actually sends — `2026-07-31T21:00:00.000Z`.
    private static let fractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// The same instant without milliseconds, which the default formatter needs
    /// and the fractional one rejects outright.
    private static let wholeSeconds = ISO8601DateFormatter()
}

/// Every `sc --json` response is wrapped in `{ok, command, data: {result}}`.
struct Envelope<T: Decodable>: Decodable {
    let ok: Bool
    let error: String?
    let data: Payload<T>?

    struct Payload<U: Decodable>: Decodable {
        let result: U?
    }
}

struct OverviewResult: Decodable {
    let valuation: Valuation
    let performance: [PerformanceEntry]?
    let timestamps: Timestamps?

    struct Valuation: Decodable {
        let total: Double
    }

    /// When the figures were struck, as opposed to when we asked for them.
    ///
    /// `valuation_timestamp_utc` is the broker's own as-of time and sits at the
    /// previous session's close outside trading hours — the live account reports
    /// Friday 21:00 UTC all weekend. That is the difference between "we fetched this
    /// a minute ago" and "this number is a minute old", and the footer used to claim
    /// the second while only knowing the first.
    struct Timestamps: Decodable {
        let valuationTimestampUtc: String?

        enum CodingKeys: String, CodingKey {
            case valuationTimestampUtc = "valuation_timestamp_utc"
        }
    }

    /// The valuation's as-of time, or `nil` when absent or unparseable.
    var valuationDate: Date? {
        timestamps?.valuationTimestampUtc.flatMap(WireTimestamp.parse)
    }

    struct PerformanceEntry: Decodable {
        let timeframe: String
        let simpleAbsoluteReturn: Double?
    }

    /// Every window the payload reports, keyed by the domain type.
    ///
    /// Unrecognised `timeframe` values are skipped rather than failing the decode:
    /// this is the same call the portfolio valuation comes from, so a broker that
    /// adds a window must not be able to take the whole read down.
    ///
    /// Note what is *not* available. No entry reports a percentage: as of sc 0.6.0
    /// each one carries `timeframe` and `simpleAbsoluteReturn` and nothing more.
    /// Versions through 0.5.0 did include a `performance` field, which by its name
    /// was the percentage — and which the live CLI returned as `0` for every window,
    /// including ones with a four-figure absolute return. It was never read here,
    /// and 0.6.0 removed it. Percentages are derived in `MarketMove` instead.
    var trailingReturns: [ReturnWindow: Double] {
        (performance ?? []).reduce(into: [:]) { windows, entry in
            guard
                let window = ReturnWindow(rawValue: entry.timeframe),
                let gain = entry.simpleAbsoluteReturn
            else { return }
            windows[window] = gain
        }
    }
}

struct HoldingsResult: Decodable {

    let items: [Item]?

    struct Item: Decodable {
        let isin: String
        let name: String?
        let securityType: String?
        let quantity: Double?
        /// Average purchase price per share, FIFO. The only route to a cost basis:
        /// nothing else in the payload says what was paid.
        let fifoPrice: Double?
        let quoteMidPrice: Double?
        let quoteIsOutdated: Bool?
        let valuation: Double?

        enum CodingKeys: String, CodingKey {
            case isin
            case name
            case securityType = "security_type"
            case quantity
            case fifoPrice = "fifo_price"
            case quoteMidPrice = "quote_mid_price"
            case quoteIsOutdated = "quote_is_outdated"
            case valuation
        }
    }

    /// Positions with enough of a payload to draw.
    ///
    /// `isin` is the only required key, because it is the only one whose absence
    /// leaves nothing to identify a row by. A position missing its valuation or
    /// its FIFO price is skipped rather than defaulted to zero: a zero would draw
    /// as a real holding worth nothing and a cost basis of nothing, which reads as
    /// a 0% return rather than as missing data.
    var holdings: [Holding] {
        (items ?? []).compactMap { item in
            guard
                let quantity = item.quantity,
                let averageCost = item.fifoPrice,
                let valuation = item.valuation
            else { return nil }
            return Holding(
                isin: item.isin,
                name: item.name ?? item.isin,
                securityType: item.securityType ?? "",
                quantity: quantity,
                averageCost: averageCost,
                quotePrice: item.quoteMidPrice ?? 0,
                valuation: valuation,
                quoteIsOutdated: item.quoteIsOutdated ?? false
            )
        }
    }
}

struct SavingsPlansResult: Decodable {
    let totalSavingsPlanAmount: Double?
    let count: Int?
    /// Optional throughout: crypto plans carry no dynamization rate, and the
    /// fixtures captured before this field existed have no `items` at all. A
    /// required key here would fail the whole decode, which surfaces as "savings
    /// plans stopped loading" rather than as a missing rate.
    let items: [Item]?

    struct Item: Decodable {
        let amount: Double?
        /// Whole percent per year, e.g. `5` for 5% p.a.
        let dynamizationRate: Double?

        enum CodingKeys: String, CodingKey {
            case amount
            case dynamizationRate = "dynamization_rate"
        }
    }

    /// The plans' dynamization as a single annual fraction, weighted by
    /// contribution.
    ///
    /// Weighted rather than averaged flat because the rate that matters is how
    /// fast the *total* grows: a 5% rise on €300 and none on €100 is 3.75% of the
    /// €400 total, not 2.5%. Plans without a rate count as zero.
    var dynamizationRate: Double {
        guard let items, !items.isEmpty else { return 0 }
        var weighted = 0.0
        var total = 0.0
        for item in items {
            let amount = item.amount ?? 0
            guard amount > 0 else { continue }
            total += amount
            weighted += amount * (item.dynamizationRate ?? 0) / 100
        }
        guard total > 0 else { return 0 }
        return weighted / total
    }

    enum CodingKeys: String, CodingKey {
        case totalSavingsPlanAmount = "total_savings_plan_amount"
        case count
        case items
    }
}

struct TransactionsResult: Decodable {
    let items: [Item]?
    /// Present while more pages remain. The CLI returns it as `cursor`.
    let cursor: String?

    struct Item: Decodable {
        let amount: Double?
        /// `DEPOSIT`, `WITHDRAWAL`, `INTEREST`, … — absent on security trades.
        let cashTransactionType: String?

        enum CodingKeys: String, CodingKey {
            case amount
            case cashTransactionType = "cash_transaction_type"
        }
    }

    /// An empty cursor string is as good as none; the CLI has returned both.
    var nextCursor: String? {
        guard let cursor, !cursor.isEmpty else { return nil }
        return cursor
    }

    /// Deposits less withdrawals. Withdrawal amounts arrive already negative, so
    /// both are simply summed.
    var netExternalFlow: Double {
        (items ?? []).reduce(into: 0.0) { total, item in
            switch item.cashTransactionType {
            case CashTransactionType.deposit, CashTransactionType.withdrawal:
                total += item.amount ?? 0
            default:
                break
            }
        }
    }
}

enum CashTransactionType {
    static let deposit = "DEPOSIT"
    static let withdrawal = "WITHDRAWAL"
}

struct WhoAmIResult: Decodable {
    let personOverview: PersonOverview?

    struct PersonOverview: Decodable {
        let personalDetails: PersonalDetails?
    }

    struct PersonalDetails: Decodable {
        let firstName: String?
    }
}
