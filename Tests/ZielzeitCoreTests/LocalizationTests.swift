import XCTest
@testable import ZielzeitCore

/// The German half of the app.
///
/// Every test here sets `AppLanguage.current` and puts it back, because it is
/// process-wide state and the other 229 tests assert English. `defer` rather than
/// `tearDown` so a failure part-way through still restores it.
final class LocalizationTests: XCTestCase {

    private func inGerman(_ body: () throws -> Void) rethrows {
        let previous = AppLanguage.current
        AppLanguage.current = .german
        defer { AppLanguage.current = previous }
        try body()
    }

    // MARK: - Picking a language

    func testEnglishIsTheDefaultSoNonAppCallersAreDeterministic() {
        XCTAssertEqual(AppLanguage.current, .english)
    }

    func testRegionalGermanStillCountsAsGerman() {
        XCTAssertEqual(AppLanguage.preferred(from: ["de-AT"]), .german)
        XCTAssertEqual(AppLanguage.preferred(from: ["de-DE", "en-US"]), .german)
        XCTAssertEqual(AppLanguage.preferred(from: ["de"]), .german)
    }

    func testFirstSupportedLanguageWins() {
        XCTAssertEqual(AppLanguage.preferred(from: ["en-GB", "de-DE"]), .english)
        // An unsupported language ahead of a supported one is skipped rather than
        // ending the search — a Mac set to French then German should read German.
        XCTAssertEqual(AppLanguage.preferred(from: ["fr-FR", "de-DE"]), .german)
    }

    func testUnsupportedLanguagesFallBackToEnglish() {
        XCTAssertEqual(AppLanguage.preferred(from: ["fr-FR", "it-IT"]), .english)
        XCTAssertEqual(AppLanguage.preferred(from: []), .english)
    }

    // MARK: - The reader's own choice

    /// A fresh defaults suite per test, so a stored choice cannot leak into the
    /// next one or into the developer's real preferences.
    private func store(environment: [String: String] = [:]) -> (LanguageStore, UserDefaults) {
        let name = "com.zielzeit.tests.language.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (LanguageStore(defaults: defaults, environment: environment), defaults)
    }

    func testNoChoiceMeansFollowTheDevice() {
        let (store, _) = store()
        XCTAssertEqual(store.preference, .system)
        XCTAssertEqual(store.resolved, AppLanguage.detected)
    }

    func testAChosenLanguageIsRememberedAndUsed() {
        let (store, _) = store()
        store.setPreference(.german)
        XCTAssertEqual(store.preference, .german)
        XCTAssertEqual(store.resolved, .german)

        store.setPreference(.english)
        XCTAssertEqual(store.resolved, .english)
    }

    /// Following the device is the *absence* of a setting, so going back to it
    /// clears the key rather than storing a sentinel.
    func testGoingBackToSystemClearsTheStoredChoice() {
        let (store, defaults) = store()
        store.setPreference(.german)
        store.setPreference(.system)
        XCTAssertNil(defaults.string(forKey: "language"))
        XCTAssertEqual(store.preference, .system)
        XCTAssertEqual(store.resolved, AppLanguage.detected)
    }

    /// The override exists to render a language on demand, so a preference saved
    /// on the developer's own Mac must not defeat it.
    func testTheEnvironmentOverrideOutranksAStoredChoice() {
        let (store, _) = store(environment: ["ZIELZEIT_LANG": "de"])
        store.setPreference(.english)
        XCTAssertEqual(store.resolved, .german)
    }

    func testAnUnrecognisedStoredValueFallsBackToTheDeviceRatherThanFailing() {
        let (store, defaults) = store()
        defaults.set("klingon", forKey: "language")
        XCTAssertEqual(store.preference, .system)
        XCTAssertEqual(store.resolved, AppLanguage.detected)
    }

    func testLanguagesNameThemselves() {
        XCTAssertEqual(AppLanguage.german.endonym, "Deutsch")
        XCTAssertEqual(AppLanguage.english.endonym, "English")
        // In German too: the point of an endonym is that it does not move.
        inGerman { XCTAssertEqual(AppLanguage.english.endonym, "English") }
    }

    // MARK: - Numbers

    func testGermanPutsTheEuroSignAfterTheAmount() {
        inGerman {
            XCTAssertEqual(Format.euro(100_000), "100\u{202F}000\u{202F}€")
            XCTAssertEqual(Format.euro(1_234.56, decimals: 2), "1\u{202F}234,56\u{202F}€")
        }
        XCTAssertTrue(Format.euro(100_000).hasPrefix("€"))
    }

    func testGermanUsesACommaForTheDecimalSeparatorWhateverTheSystemRegion() {
        inGerman {
            XCTAssertTrue(Format.euro(12.5, decimals: 2).contains("12,50"))
            XCTAssertEqual(Format.percent(0.06), "6,0\u{202F}%")
            XCTAssertEqual(Format.percent(0.05, decimals: 0), "5\u{202F}%")
        }
    }

    func testSignedAmountsKeepTheRealMinusSign() {
        inGerman {
            XCTAssertEqual(Format.signedEuro(-240.10, decimals: 2), "−240,10\u{202F}€")
            XCTAssertEqual(Format.signedEuro(18.40, decimals: 2), "+18,40\u{202F}€")
        }
    }

    /// The hero sentence opens with "In …", so the German duration has to be in
    /// the dative — "In 15,6 Jahre" is the sort of mistake that makes the whole
    /// translation look unread.
    func testGermanDurationsAreDeclinedForTheHeroSentence() {
        inGerman {
            XCTAssertEqual(Format.duration(months: 188.4), "15,7 Jahren")
            XCTAssertEqual(Format.duration(months: 8), "8 Monaten")
            XCTAssertEqual(Format.duration(months: 1), "einem Monat")
            XCTAssertEqual(Format.duration(months: 0.4), "unter einem Monat")
        }
    }

    // MARK: - Rows

    /// `letzter Schluss` is wider than the market column, and without the padding
    /// floor the label would butt straight against the arrow.
    func testALabelWiderThanItsColumnStillGetsASpaceBeforeTheArrow() {
        inGerman {
            let move = MarketMove(window: .intraday, gain: -12.5, total: 10_000, isCurrentSession: false)
            XCTAssertEqual(move.windowLabel, "letzter Schluss")
            XCTAssertTrue(Format.moveRow(move).contains("letzter Schluss ▼"), Format.moveRow(move))
        }
    }

    func testGermanRowsUseTheGermanUnits() {
        inGerman {
            let row = Format.requiredRow((year: 2030, required: 770, delta: 358))
            XCTAssertTrue(row.hasPrefix("Ende 2030"), row)
            XCTAssertTrue(row.contains("/Mon."), row)
            XCTAssertTrue(row.contains("ggü. heute"), row)

            let unreachable = Format.requiredRow((year: 2030, required: 0, delta: nil))
            XCTAssertTrue(unreachable.contains("Wachstum allein reicht"), unreachable)
        }
    }

    func testScenarioLabelsAndTheHeadlineStayInStep() {
        inGerman {
            XCTAssertEqual(Report.realizedLabel, "Dein Tempo")
            let report = germanReport()
            // The whole highlight mechanism keys off this equality: the emphasised
            // row, the thick curve and the hero hue all compare against it.
            XCTAssertTrue(report.scenarios.contains { $0.label == report.headlineLabel })
        }
    }

    func testSummaryRowsCarryAStableKindSoTheIconsSurviveTranslation() {
        inGerman {
            let rows = germanReport().summaryRows
            XCTAssertEqual(rows.map(\.kind), [.portfolio, .saving, .pastYear])
            XCTAssertEqual(rows.map(\.label), ["Portfolio", "Sparrate", "Vorjahr"])
        }
    }

    // MARK: - Disclaimer

    /// The same one-line-under-70-characters rule the English disclaimer is held
    /// to. German is the language that breaks it, so it is the one worth pinning.
    func testEveryGermanCaveatFitsOnOneLine() {
        inGerman {
            for line in Disclaimer.assumptions(for: germanReport()) + [Disclaimer.notAdvice] {
                XCTAssertFalse(line.contains("\n"), line)
                XCTAssertLessThan(line.count, 70, "too long (\(line.count)): \(line)")
            }
        }
    }

    func testGermanCaveatsQuoteTheFiguresOnScreen() {
        inGerman {
            let report = germanReport()
            let lines = Disclaimer.assumptions(for: report)
            XCTAssertTrue(lines.contains { $0.contains(Format.percent(report.headlineRate)) }, "\(lines)")
            XCTAssertTrue(lines.contains { $0.contains("380") && $0.contains("/Mon.") }, "\(lines)")
        }
    }

    // MARK: - Whole report

    func testTheTextReportComesOutInGerman() {
        inGerman {
            let text = germanReport().textReport()
            for heading in ["Markt", "Prognosen", "Erreichen bis"] {
                XCTAssertTrue(text.contains(heading), heading)
            }
            XCTAssertFalse(text.contains("Projections"), text)
            XCTAssertFalse(text.contains("Your pace"), text)
        }
    }

    func testMenuBarTitleIsGermanAndSpacesThePercentSign() {
        inGerman {
            XCTAssertTrue(germanReport().statusTitle.contains("\u{202F}%"))
            let reached = Report(goal: 1_000, snapshot: snapshot(total: 2_000), now: now, calendar: calendar)
            XCTAssertEqual(reached.menuBarText, "Erreicht")
            XCTAssertTrue(reached.statusTitle.hasSuffix("erreicht"))
        }
    }

    func testTheStarAskIsTranslatedAndNotTheLoanword() {
        XCTAssertEqual(Strings.starOnGitHub, "Star on GitHub")
        inGerman {
            // `Stern`, matching GitHub's own German interface, so the item does not
            // read as the one untranslated string in the menu.
            XCTAssertEqual(Strings.starOnGitHub, "Auf GitHub einen Stern geben")
        }
    }

    // MARK: - Fixtures
    //
    // Shaped, not captured: no real balance, contribution or account figure.

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 31))!
    }

    private func snapshot(total: Double = 11_795.78) -> PortfolioSnapshot {
        PortfolioSnapshot(
            total: total,
            oneYearGain: 1_819.42,
            monthlySavings: 380,
            savingsPlanCount: 2,
            dynamizationRate: 0.05
        )
    }

    private func germanReport() -> Report {
        Report(goal: 100_000, snapshot: snapshot(), now: now, calendar: calendar)
    }
}
