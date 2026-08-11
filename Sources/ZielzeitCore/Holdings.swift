import Foundation

/// One position, as the broker reports it.
///
/// Everything here except `cost` and what derives from it is read straight from
/// the payload. `cost` is the one figure the broker does not state: it comes from
/// the FIFO price, which is why a position's gain is *unrealised* and per-lot
/// rather than a number the account has anywhere.
public struct Holding: Equatable, Identifiable {

    public let isin: String
    public let name: String

    /// `ETF`, `STOCK`, … — the broker's own vocabulary, passed through.
    public let securityType: String

    public let quantity: Double

    /// FIFO average purchase price per share, in the quote currency.
    public let averageCost: Double

    /// Latest mid price. Kept beside `valuation` rather than used to recompute it:
    /// the broker's own valuation is the authority, and multiplying here would
    /// invent a second answer that disagrees in the last cent.
    public let quotePrice: Double

    public let valuation: Double

    /// The broker's own flag on the quote behind `valuation`.
    ///
    /// Worth surfacing rather than swallowing: a stale quote makes both the
    /// valuation and every return derived from it older than the page implies.
    public let quoteIsOutdated: Bool

    public var id: String { isin }

    public init(
        isin: String,
        name: String,
        securityType: String = "ETF",
        quantity: Double,
        averageCost: Double,
        quotePrice: Double,
        valuation: Double,
        quoteIsOutdated: Bool = false
    ) {
        self.isin = isin
        self.name = name
        self.securityType = securityType
        self.quantity = quantity
        self.averageCost = averageCost
        self.quotePrice = quotePrice
        self.valuation = valuation
        self.quoteIsOutdated = quoteIsOutdated
    }

    /// What was paid for the shares now held.
    public var cost: Double { quantity * averageCost }

    /// Today's valuation less what was paid.
    public var unrealisedGain: Double { valuation - cost }

    /// Return since purchase as a fraction, or `nil` when there is no cost to
    /// divide by — a position received rather than bought would otherwise report
    /// an infinite gain.
    public var sinceBuyReturn: Double? {
        cost > 0 ? unrealisedGain / cost : nil
    }
}

/// Every position, and the sums the page reads off them.
public struct HoldingsSnapshot: Equatable {

    public let items: [Holding]

    public init(items: [Holding]) {
        self.items = items
    }

    /// The positions' own valuations, summed.
    ///
    /// Deliberately *not* `PortfolioSnapshot.total`, and the two will not always
    /// agree: they come from separate calls whose quotes were struck seconds
    /// apart, so a live account can show a few euros of difference. Weights and
    /// shares are computed against this one so that everything on the page adds up
    /// to what the page itself displays, rather than to a figure fetched
    /// elsewhere.
    public var total: Double { items.reduce(0) { $0 + $1.valuation } }

    public var cost: Double { items.reduce(0) { $0 + $1.cost } }

    public var unrealisedGain: Double { total - cost }

    /// The portfolio's own return since purchase, as a fraction.
    ///
    /// This is the figure the broker reports as `since_buy.performance` on a
    /// portfolio group, and deriving it here rather than reading it there keeps
    /// the page to one call and one arithmetic.
    public var sinceBuyReturn: Double? {
        cost > 0 ? unrealisedGain / cost : nil
    }

    /// Share of the page's total, or `nil` when there is no total to divide by.
    public func weight(of holding: Holding) -> Double? {
        total > 0 ? holding.valuation / total : nil
    }

    /// Largest valuation first, which is the order every list on the page uses.
    public var byValuation: [Holding] {
        items.sorted { $0.valuation > $1.valuation }
    }

    /// True when any quote behind these figures is stale, so the page can say so
    /// once instead of marking five rows.
    public var hasOutdatedQuote: Bool {
        items.contains { $0.quoteIsOutdated }
    }
}

/// Source of per-position data, kept separate from `PortfolioProviding` so the
/// popover's main path does not gain a dependency on a call it never makes.
public protocol HoldingsProviding {
    func fetchHoldings() throws -> HoldingsSnapshot
}
