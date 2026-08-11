import XCTest
@testable import ZielzeitCore

/// Per-position decoding and the arithmetic the holdings page reads off it.
///
/// Fixtures are shaped from `sc broker holdings --json` with placeholder ISINs and
/// invented amounts — the shape is real, the account is not.
final class HoldingsTests: XCTestCase {

    private let holdingsJSON = """
    {"ok":true,"command":"broker.holdings","data":{"account_id":"acc","portfolio_id":"pf",
    "result":{"account_id":"acc","count":2,"items":[
    {"blocked_quantity":0,"fifo_price":8.0,"isin":"IE00EXAMPLE01",
    "name":"Example World Small Cap (Acc)","pending_quantity":0,"quantity":100.0,
    "quote_currency":"EUR","quote_is_outdated":false,"quote_mid_price":10.0,
    "quote_timestamp_utc":"2026-08-11T09:51:44.310Z","security_type":"ETF",
    "valuation":1000.0,"valuation_currency":"EUR"},
    {"blocked_quantity":0,"fifo_price":20.0,"isin":"IE00EXAMPLE02",
    "name":"Example Europe (Acc)","pending_quantity":0,"quantity":50.0,
    "quote_currency":"EUR","quote_is_outdated":true,"quote_mid_price":22.0,
    "quote_timestamp_utc":"2026-08-11T09:51:27.961Z","security_type":"ETF",
    "valuation":1100.0,"valuation_currency":"EUR"}],
    "portfolio_id":"pf"}}}
    """

    /// One position has no `valuation` and one has no `fifo_price` — both are
    /// unusable, and neither may become a zero.
    private let partialHoldingsJSON = """
    {"ok":true,"command":"broker.holdings","data":{"account_id":"acc",
    "result":{"count":3,"items":[
    {"fifo_price":8.0,"isin":"IE00EXAMPLE01","name":"Example Complete (Acc)",
    "quantity":100.0,"quote_mid_price":10.0,"security_type":"ETF","valuation":1000.0},
    {"fifo_price":8.0,"isin":"IE00EXAMPLE02","name":"Example No Valuation (Acc)",
    "quantity":100.0,"quote_mid_price":10.0,"security_type":"ETF"},
    {"isin":"IE00EXAMPLE03","name":"Example No Cost Basis (Acc)","quantity":100.0,
    "quote_mid_price":10.0,"security_type":"ETF","valuation":1000.0}]}}}
    """

    private func data(_ string: String) -> Data { Data(string.utf8) }

    private func decode(_ json: String) throws -> HoldingsSnapshot {
        let result = try ScalableClient.decode(
            HoldingsResult.self, from: data(json), command: "broker holdings"
        )
        return HoldingsSnapshot(items: result.holdings)
    }

    // MARK: - Decoding

    func testDecodesEveryPosition() throws {
        let snapshot = try decode(holdingsJSON)
        XCTAssertEqual(snapshot.items.count, 2)

        let first = snapshot.items[0]
        XCTAssertEqual(first.isin, "IE00EXAMPLE01")
        XCTAssertEqual(first.name, "Example World Small Cap (Acc)")
        XCTAssertEqual(first.securityType, "ETF")
        XCTAssertEqual(first.quantity, 100)
        XCTAssertEqual(first.averageCost, 8)
        XCTAssertEqual(first.quotePrice, 10)
        XCTAssertEqual(first.valuation, 1000)
        XCTAssertFalse(first.quoteIsOutdated)
    }

    /// A missing valuation or cost basis drops the row. Defaulting either to zero
    /// would draw a real holding worth nothing at a 0% return.
    func testSkipsPositionsMissingValuationOrCostBasis() throws {
        let snapshot = try decode(partialHoldingsJSON)
        XCTAssertEqual(snapshot.items.map(\.isin), ["IE00EXAMPLE01"])
    }

    func testCarriesTheBrokersOutdatedQuoteFlag() throws {
        let snapshot = try decode(holdingsJSON)
        XCTAssertFalse(snapshot.items[0].quoteIsOutdated)
        XCTAssertTrue(snapshot.items[1].quoteIsOutdated)
        XCTAssertTrue(snapshot.hasOutdatedQuote)
    }

    // MARK: - Per-position arithmetic

    func testCostIsQuantityTimesAveragePrice() {
        let holding = Holding(
            isin: "IE00EXAMPLE01", name: "Example", quantity: 100,
            averageCost: 8, quotePrice: 10, valuation: 1000
        )
        XCTAssertEqual(holding.cost, 800)
        XCTAssertEqual(holding.unrealisedGain, 200)
        XCTAssertEqual(try XCTUnwrap(holding.sinceBuyReturn), 0.25, accuracy: 1e-12)
    }

    func testALosingPositionReportsANegativeGain() {
        let holding = Holding(
            isin: "IE00EXAMPLE01", name: "Example", quantity: 100,
            averageCost: 12, quotePrice: 10, valuation: 1000
        )
        XCTAssertEqual(holding.unrealisedGain, -200)
        XCTAssertEqual(try XCTUnwrap(holding.sinceBuyReturn), -1.0 / 6.0, accuracy: 1e-12)
    }

    /// A position with no cost — transferred in rather than bought — has no return
    /// to state, as opposed to an infinite one.
    func testReturnIsAbsentWithoutACostBasis() {
        let holding = Holding(
            isin: "IE00EXAMPLE01", name: "Example", quantity: 100,
            averageCost: 0, quotePrice: 10, valuation: 1000
        )
        XCTAssertEqual(holding.cost, 0)
        XCTAssertNil(holding.sinceBuyReturn)
    }

    // MARK: - Portfolio arithmetic

    func testSumsAgreeWithThePositions() throws {
        let snapshot = try decode(holdingsJSON)
        XCTAssertEqual(snapshot.total, 2100)
        XCTAssertEqual(snapshot.cost, 1800)
        XCTAssertEqual(snapshot.unrealisedGain, 300)
        XCTAssertEqual(try XCTUnwrap(snapshot.sinceBuyReturn), 300.0 / 1800.0, accuracy: 1e-12)
    }

    func testWeightsAreShareOfThePagesOwnTotal() throws {
        let snapshot = try decode(holdingsJSON)
        let weight = try XCTUnwrap(snapshot.weight(of: snapshot.items[0]))
        XCTAssertEqual(weight, 1000.0 / 2100.0, accuracy: 1e-12)
    }

    func testEmptyPortfolioHasNoTotalToDivideBy() {
        let snapshot = HoldingsSnapshot(items: [])
        XCTAssertEqual(snapshot.total, 0)
        XCTAssertNil(snapshot.sinceBuyReturn)
    }

    func testOrdersByValuationDescending() throws {
        let snapshot = try decode(holdingsJSON)
        XCTAssertEqual(snapshot.byValuation.map(\.isin), ["IE00EXAMPLE02", "IE00EXAMPLE01"])
    }
}
