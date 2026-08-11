import Foundation

/// The language Zielzeit speaks.
///
/// Deliberately not `.lproj` bundles. This package ships no resources at all —
/// the icons are drawn in code and the app bundle is assembled by hand in the
/// Makefile — so a `Bundle.module` lookup would mean a resource bundle that has
/// to be copied into `Contents/Resources` correctly or the app silently falls
/// back to keys. A Swift table cannot half-load, and it keeps `--once`, the
/// tests and the app reading from exactly one source.
public enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case german = "de"

    /// The language everything renders in.
    ///
    /// **Defaults to English and is set once at startup**, in `main`, from
    /// `detected`. That direction matters: tests and any other non-app caller get
    /// a deterministic language without having to pin one, and only the app —
    /// which is the only thing with a device to read a preference from — opts in
    /// to detection.
    public static var current: AppLanguage = .english

    /// The language the device asks for, or English when it asks for neither.
    public static var detected: AppLanguage {
        preferred(from: Locale.preferredLanguages)
    }

    /// How the language is named in its own language, which is how every language
    /// picker worth using names them: a reader who has landed in the wrong one
    /// cannot read the list if it is written in the language they cannot read.
    public var endonym: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        }
    }

    /// First supported language in a preference list, matched on the language
    /// subtag so `de-AT` and `de-DE` both land on German.
    public static func preferred(from languages: [String]) -> AppLanguage {
        for identifier in languages {
            if let language = match(identifier) { return language }
        }
        return .english
    }

    private static func match(_ identifier: String) -> AppLanguage? {
        let subtag = identifier.split(separator: "-").first.map(String.init)?.lowercased()
        return AppLanguage(rawValue: subtag ?? identifier.lowercased())
    }

    /// Whether "€" comes before the number.
    ///
    /// It does in English and does not in German, where DIN 5008 puts the symbol
    /// after the amount. Two different rules rather than one house style, because
    /// a currency in the wrong position is the sort of thing that reads as a
    /// translation nobody checked.
    public var currencySymbolLeads: Bool { self == .english }

    /// Locale for numbers and dates.
    ///
    /// English keeps `Locale.current` rather than forcing `en_US`: the app has
    /// always taken its separators from the system, and a German Mac reading an
    /// English UI has been showing `€11 795,78` since the first release. German
    /// is pinned, so `ZIELZEIT_LANG=de` on an English Mac still reads as German
    /// rather than as German words around English numbers.
    public var locale: Locale {
        switch self {
        case .english: return .current
        case .german: return Locale(identifier: "de_DE")
        }
    }
}

/// What the reader has chosen in the menu.
///
/// `system` is a real third option rather than the absence of a choice: it means
/// "keep following the Mac", so a user who moves their Mac to German gets a
/// German Zielzeit without going back into the menu. Storing the resolved
/// language instead would silently freeze that.
public enum LanguagePreference: String, CaseIterable, Sendable {
    case system
    case english = "en"
    case german = "de"

    /// The language this pins, or `nil` for "whatever the device says".
    public var language: AppLanguage? {
        switch self {
        case .system: return nil
        case .english: return .english
        case .german: return .german
        }
    }

    public init(language: AppLanguage) {
        self = language == .german ? .german : .english
    }
}

/// Persistence for the language choice, in the same defaults domain as the goal.
public struct LanguageStore {

    private enum Key {
        static let language = "language"
    }

    private let defaults: UserDefaults
    private let environment: [String: String]

    public init(
        defaults: UserDefaults? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.defaults = defaults ?? Defaults.shared()
        self.environment = environment
    }

    /// What the reader picked. Unset — and anything unrecognised, such as a value
    /// left behind by a future version — reads as `system`.
    public var preference: LanguagePreference {
        guard let raw = defaults.string(forKey: Key.language) else { return .system }
        return LanguagePreference(rawValue: raw) ?? .system
    }

    public func setPreference(_ preference: LanguagePreference) {
        // Removed rather than stored as "system", so following the device is the
        // absence of a setting and a future rename of the sentinel cannot strand
        // anyone in a language they did not choose.
        if preference == .system {
            defaults.removeObject(forKey: Key.language)
        } else {
            defaults.set(preference.rawValue, forKey: Key.language)
        }
    }

    /// The language to run in: the environment override first, then the reader's
    /// choice, then the device.
    ///
    /// `ZIELZEIT_LANG` outranks the stored preference deliberately — it exists to
    /// render a language on demand for screenshots and review, and a setting saved
    /// on the developer's own Mac must not defeat that.
    public var resolved: AppLanguage {
        if let forced = environment["ZIELZEIT_LANG"],
           let language = LanguagePreference(rawValue: forced.lowercased())?.language {
            return language
        }
        return preference.language ?? .detected
    }
}

/// Every string the app shows, in both languages.
///
/// One table rather than strings spread through the views, so a line can be
/// checked against its translation without hunting, and so the popover and
/// `--once` cannot word the same thing two ways.
public enum Strings {

    /// German if that is the current language, English otherwise.
    static func pick(_ english: String, _ german: String) -> String {
        AppLanguage.current == .german ? german : english
    }

    // MARK: - Scenarios

    public static var cautious: String { pick("Cautious", "Vorsichtig") }
    public static var moderate: String { pick("Moderate", "Moderat") }
    public static var yourPace: String { pick("Your pace", "Dein Tempo") }

    // MARK: - Units and small words

    /// Suffix on a monthly amount, e.g. `€380/mo`.
    public static var perMonth: String { pick("/mo", "/Mon.") }
    /// Suffix on an annual rate, e.g. `+5%/yr`.
    public static var perYear: String { pick("/yr", "/Jahr") }
    public static var never: String { pick("never", "nie") }
    public static var reached: String { pick("reached", "erreicht") }
    public static var reachedCapitalized: String { pick("Reached", "Erreicht") }

    // MARK: - Market windows

    public static var windowToday: String { pick("today", "heute") }
    public static var windowTwoDays: String { pick("2 days", "2 Tage") }
    public static var windowThisWeek: String { pick("this week", "diese Woche") }
    public static var windowThisMonth: String { pick("this month", "dieser Monat") }
    public static var windowThreeMonths: String { pick("3 months", "3 Monate") }
    public static var windowSixMonths: String { pick("6 months", "6 Monate") }
    public static var windowPastYear: String { pick("past year", "letztes Jahr") }
    public static var windowAllTime: String { pick("all time", "gesamt") }
    public static var windowLastSession: String { pick("last session", "letzter Schluss") }

    // MARK: - Summary rows

    public static var portfolio: String { pick("Portfolio", "Portfolio") }
    public static var saving: String { pick("Saving", "Sparrate") }
    /// "Vorjahr" rather than "Letztes Jahr", which is exactly as wide as its own
    /// column in the text report and would leave the value one space out of line
    /// with the rows above it.
    public static var pastYear: String { pick("Past year", "Vorjahr") }

    public static func savingsPlans(_ count: Int) -> String {
        AppLanguage.current == .german
            ? "\(count) \(count == 1 ? "Plan" : "Pläne")"
            : "\(count) \(count == 1 ? "plan" : "plans")"
    }

    // MARK: - Rows and sections

    public static var notEnoughHistory: String { pick("not enough history", "zu wenig Historie") }
    public static var neverAtThisPace: String { pick("never at this pace", "nie in diesem Tempo") }
    public static var nothingGrowthGetsThere: String {
        pick("nothing — growth alone gets there", "nichts — Wachstum allein reicht")
    }
    public static var versusNow: String { pick("vs now", "ggü. heute") }

    public static func endOf(_ year: Int) -> String {
        pick("end of \(year)", "Ende \(year)")
    }

    public static func whatIfHeading(rate: String) -> String {
        pick("If I saved more (at \(rate))", "Wenn ich mehr spare (bei \(rate))")
    }

    public static var marketHeading: String { pick("Market", "Markt") }
    public static var projectionsHeading: String { pick("Projections", "Prognosen") }
    public static var todaysMoneyHeading: String { pick("In today's money", "In heutigem Geld") }
    public static var toReachItByHeading: String { pick("To reach it by", "Erreichen bis") }

    public static func todaysMoneyLine(goal: String, year: Int, real: String, inflation: String) -> String {
        pick(
            "\(goal) in \(year) ≈ \(real)  (at \(inflation) inflation)",
            "\(goal) in \(year) ≈ \(real)  (bei \(inflation) Inflation)"
        )
    }

    // MARK: - Disclaimer

    public static var disclaimerHeadline: String {
        pick("Projections, not predictions", "Prognosen, keine Vorhersagen")
    }
    public static var notAdvice: String { pick("Not financial advice.", "Keine Finanzberatung.") }

    public static func assumesRate(_ rate: String) -> String {
        pick(
            "Assumes \(rate) every year, from one trailing year.",
            "Nimmt \(rate) pro Jahr an, aus einem Jahr Historie."
        )
    }
    public static var paceAssumesDeposits: String {
        pick(
            "Pace assumes deposits ran at today's rate all year.",
            "Tempo unterstellt die heutige Sparrate für das Jahr."
        )
    }
    public static func underAYearOfHistory(_ rate: String) -> String {
        pick(
            "Under a year of history — assumes \(rate), not your own pace.",
            "Unter einem Jahr Historie — nimmt \(rate) an, nicht dein Tempo."
        )
    }
    public static var compoundsSmoothly: String {
        pick("Compounds smoothly. Real returns don't.", "Rechnet mit glattem Zins. Echte Renditen nicht.")
    }
    public static func assumesContribution(_ amount: String, stepUp: String?) -> String {
        var line = pick("Assumes \(amount)\(perMonth)", "Nimmt \(amount)\(perMonth) an")
        if let stepUp {
            line += pick(", rising \(stepUp)\(perYear)", ", +\(stepUp)\(perYear)")
        }
        line += pick(", never paused.", ", nie pausiert.")
        return line
    }
    public static var stepUpDateGuessed: String {
        pick(
            "Step-up date is guessed; Scalable doesn't publish it.",
            "Erhöhungsdatum geschätzt; Scalable nennt es nicht."
        )
    }
    public static func beforeTaxWithInflation(_ rate: String) -> String {
        pick(
            "Before tax; today's money assumes \(rate) inflation.",
            "Vor Steuern; heutiges Geld bei \(rate) Inflation."
        )
    }
    public static var beforeTaxAndInflation: String {
        pick("Before tax and inflation.", "Vor Steuern und Inflation.")
    }

    // MARK: - Errors

    public static func cliNotFound(path: String) -> String {
        pick("Scalable CLI not found at \(path)", "Scalable CLI nicht gefunden unter \(path)")
    }
    public static var cliTimedOut: String {
        pick("Scalable CLI timed out", "Zeitüberschreitung beim Scalable CLI")
    }
    public static var notLoggedIn: String {
        pick(
            "Not logged in — run `sc login` in a terminal",
            "Nicht angemeldet — führe `sc login` im Terminal aus"
        )
    }
    public static func unexpectedResponse(command: String) -> String {
        pick("Unexpected response from `sc \(command)`", "Unerwartete Antwort von `sc \(command)`")
    }

    // MARK: - Setup

    public static var senderNote: String {
        pick(
            "Send it from the email address registered with Scalable Capital — check the From field.",
            "Sende sie von der bei Scalable Capital registrierten E-Mail-Adresse — prüfe das Von-Feld."
        )
    }

    // MARK: - Hero

    public static var goalReached: String { pick("Goal reached", "Ziel erreicht") }
    public static var projected: String { pick("Projected", "Prognose") }
    public static var done: String { pick("Done", "Geschafft") }
    public static var notYet: String { pick("Not yet", "Noch nicht") }
    public static var notWithin100Years: String {
        pick("Not within 100 years at this pace", "Nicht in 100 Jahren in diesem Tempo")
    }

    /// The hero sentence, split so the two figures can be weighted differently
    /// from the words joining them: `In ` + duration + ` you'll have about ` +
    /// amount.
    public static var sentenceIn: String { pick("In ", "In ") }
    public static var sentenceYouWillHave: String {
        pick(" you'll have about ", " hast du etwa ")
    }

    /// `that's about ` + amount + ` in today's money`. German carries the sense in
    /// the opening words instead, so its suffix is empty.
    public static var thatsAbout: String { pick("that's about ", "das sind heute etwa ") }
    public static var inTodaysMoney: String { pick(" in today's money", "") }

    public static func amountOfGoal(_ total: String, _ goal: String) -> String {
        pick("\(total) of \(goal)", "\(total) von \(goal)")
    }

    // MARK: - Scenario list

    public static var noHistory: String { pick("no history", "keine Historie") }

    // MARK: - Sliders

    public static var saveMore: String { pick("Save more", "Mehr sparen") }
    public static func nowPerMonth(_ amount: String) -> String {
        pick("now \(amount)\(perMonth)", "jetzt \(amount)\(perMonth)")
    }
    public static var reachBy: String { pick("Reach by", "Erreichen bis") }
    public static var noSavingsNeeded: String { pick("no savings needed", "kein Sparen nötig") }
    public static func morePerMonthThanNow(_ amount: String) -> String {
        pick("\(amount)\(perMonth) more than now", "\(amount)\(perMonth) mehr als jetzt")
    }
    public static func lessPerMonthThanNow(_ amount: String) -> String {
        pick("\(amount)\(perMonth) less than now", "\(amount)\(perMonth) weniger als jetzt")
    }
    public static var toStart: String { pick("· to start", "· zu Beginn") }

    // MARK: - Goal editor

    public static var yourGoal: String { pick("Your goal", "Dein Ziel") }
    public static var whatAreYouAimingFor: String { pick("What are you aiming for?", "Was ist dein Ziel?") }
    public static var save: String { pick("Save", "Sichern") }
    public static var cancel: String { pick("Cancel", "Abbrechen") }
    public static var goalHintEmpty: String {
        pick("Try 100000, 100.000 or 100k.", "Zum Beispiel 100000, 100.000 oder 100k.")
    }
    public static var goalHintInvalid: String {
        pick("That doesn't look like an amount.", "Das sieht nicht nach einem Betrag aus.")
    }
    public static func goalHintValid(_ amount: String) -> String {
        pick("Aiming for \(amount).", "Ziel: \(amount).")
    }

    // MARK: - Empty and error states

    public static var setAGoal: String { pick("Set a goal", "Ziel festlegen") }
    public static var setAGoalMessage: String {
        pick(
            "Zielzeit needs a target amount before it can tell you when you'll reach it.",
            "Zielzeit braucht einen Zielbetrag, bevor es sagen kann, wann du ihn erreichst."
        )
    }
    public static var setGoal: String { pick("Set goal", "Ziel festlegen") }
    public static var setGoalEllipsis: String { pick("Set goal…", "Ziel festlegen…") }
    public static var cantReadPortfolio: String {
        pick("Can't read your portfolio", "Portfolio nicht lesbar")
    }
    public static var tryAgain: String { pick("Try again", "Erneut versuchen") }
    public static var readingPortfolio: String {
        pick("Reading your portfolio…", "Portfolio wird gelesen…")
    }

    // MARK: - Footer and menu

    public static func valued(_ stamp: String) -> String { pick("Valued \(stamp)", "Stand \(stamp)") }
    public static func fetched(_ stamp: String) -> String { pick("Fetched \(stamp)", "Abgerufen \(stamp)") }
    public static func updated(_ stamp: String) -> String { pick("Updated \(stamp)", "Aktualisiert \(stamp)") }
    public static func couldNotUpdate(_ reason: String) -> String {
        pick("Couldn't update: \(reason)", "Aktualisierung fehlgeschlagen: \(reason)")
    }
    public static var refreshNow: String { pick("Refresh now", "Jetzt aktualisieren") }
    public static var launchAtLogin: String { pick("Launch at login", "Beim Anmelden starten") }
    public static var quitZielzeit: String { pick("Quit Zielzeit", "Zielzeit beenden") }
    /// `Updates`, not `Aktualisierungen`: `Jetzt aktualisieren` sits one line
    /// above this in the same menu, and the two would read as variants of each
    /// other. The loanword is what a German reader expects on this menu item.
    public static var checkForUpdates: String { pick("Check for updates", "Nach Updates suchen") }
    /// Disclosure, not decoration. Updates install silently, so this line is the
    /// only place the app says that it does — and the version is what makes a
    /// report of "I'm on 1.1 and you say 1.3" actionable at all.
    public static func versionLine(_ version: String) -> String {
        pick(
            "Zielzeit \(version) · updates automatically",
            "Zielzeit \(version) · aktualisiert sich automatisch"
        )
    }
    /// The only ask the app ever makes of a reader, and it opens a browser rather
    /// than doing anything itself: a star is a write on the reader's own GitHub
    /// account, which nothing here has — or should want — the credentials for.
    ///
    /// `Stern`, not `Star`: unlike `Updates` one line up, the German word is the
    /// one GitHub's own interface uses, so the loanword would be the odd choice
    /// here rather than the expected one.
    public static var starOnGitHub: String {
        pick("Star on GitHub", "Auf GitHub einen Stern geben")
    }
    public static var couldNotChangeLoginItem: String {
        pick("Could not change the login item", "Login-Objekt konnte nicht geändert werden")
    }

    // MARK: - Market chip

    public static func chipHelp(_ window: String) -> String {
        pick(
            "\(window) — click for another period",
            "\(window) — klicken für einen anderen Zeitraum"
        )
    }

    // MARK: - Language menu

    /// Names of the languages themselves come from `AppLanguage.endonym`, so the
    /// list stays readable to someone who has landed in the wrong one.
    public static var language: String { pick("Language", "Sprache") }
    public static var systemLanguage: String { pick("System", "System") }

    // MARK: - Menu bar

    public static var menuBarSetUp: String { pick("Set up", "Einrichten") }
    /// Shorter than the popover's button: this sits in the menu bar, where every
    /// character costs width the user did not choose to give up.
    public static var menuBarSetGoal: String { pick("Set goal", "Ziel setzen") }

    // MARK: - Setup checklist

    public static var connectYourPortfolio: String { pick("Connect your portfolio", "Portfolio verbinden") }
    public static var threeStepsToConnect: String { pick("Three steps to connect", "Drei Schritte zum Verbinden") }
    public static var almostThere: String { pick("Almost there", "Fast geschafft") }
    public static var setupIntro: String {
        pick(
            "Zielzeit reads your portfolio through Scalable Capital's official CLI, which is in beta — so it has to allowlist your Mac first.",
            "Zielzeit liest dein Portfolio über das offizielle CLI von Scalable Capital. Es ist in der Beta — dein Mac muss dafür erst freigeschaltet werden."
        )
    }
    public static var installTheCLI: String { pick("Install the Scalable CLI", "Scalable CLI installieren") }
    public static var installationInstructions: String {
        pick("Installation instructions", "Installationsanleitung")
    }
    public static var accessRequested: String { pick("Access requested", "Zugang angefragt") }
    public static var requestBetaAccess: String { pick("Request beta access", "Beta-Zugang anfragen") }
    public static var willReplyOnceAllowlisted: String {
        pick(
            "Scalable Capital will reply once your Mac is allowlisted. Then sign in below.",
            "Scalable Capital meldet sich, sobald dein Mac freigeschaltet ist. Danach unten anmelden."
        )
    }
    public static func sendsYourCodeTo(_ address: String) -> String {
        pick("Sends your installation code to \(address).", "Sendet deinen Installationscode an \(address).")
    }
    public static var sendAgain: String { pick("Send again", "Erneut senden") }
    public static var requestAccess: String { pick("Request access", "Zugang anfragen") }
    public static var noInstallationCode: String {
        pick(
            "Couldn't read an installation code from the CLI.",
            "Das CLI hat keinen Installationscode geliefert."
        )
    }
    public static var signIn: String { pick("Sign in", "Anmelden") }
    public static var signInExplanation: String {
        pick(
            "Run this yourself in Terminal — Zielzeit never handles your credentials. The flag keeps the session read-only.",
            "Führe das selbst im Terminal aus — Zielzeit sieht deine Zugangsdaten nie. Das Flag hält die Sitzung schreibgeschützt."
        )
    }
    public static var checkAgain: String { pick("Check again", "Erneut prüfen") }
    public static var copy: String { pick("Copy", "Kopieren") }
    public static var openInTerminal: String { pick("Open in Terminal", "Im Terminal öffnen") }

    // MARK: - Text mode

    public static var noGoalSet: String {
        pick(
            "No goal set. Set one in the app, or pass ZIELZEIT_GOAL=100000.",
            "Kein Ziel gesetzt. Lege eins in der App fest oder setze ZIELZEIT_GOAL=100000."
        )
    }
    public static func errorPrefix(_ message: String) -> String {
        pick("Error: \(message)", "Fehler: \(message)")
    }
    public static var notConnectedYet: String {
        pick(
            "Zielzeit isn't connected to your portfolio yet.",
            "Zielzeit ist noch nicht mit deinem Portfolio verbunden."
        )
    }
    public static var stepInstallCLI: String {
        pick("1. Install the Scalable CLI (it's in beta):", "1. Scalable CLI installieren (Beta):")
    }
    public static var stepRequestAllowlisting: String {
        pick(
            "2. Request allowlisting — run `sc installation-code`, then email the code to",
            "2. Freischaltung anfragen — führe `sc installation-code` aus und maile den Code an"
        )
    }
    public static var stepSignIn: String { pick("3. Sign in:", "3. Anmelden:") }
    public static func subjectNote(_ subject: String) -> String {
        pick("(subject: \(subject))", "(Betreff: \(subject))")
    }
    public static func yourInstallationCode(_ code: String) -> String {
        pick("Your installation code: \(code)", "Dein Installationscode: \(code)")
    }
    public static var ifNotAllowlistedEmail: String {
        pick(
            "If you haven't been allowlisted yet, email the code to",
            "Falls du noch nicht freigeschaltet bist, maile den Code an"
        )
    }
    public static var thenSignIn: String { pick("Then sign in:", "Dann anmelden:") }

    // MARK: - Holdings page

    /// The page's own name, on the button that opens it and in its header.
    ///
    /// "Positionen" rather than "Beteiligungen": it is the word a German broker
    /// statement uses for the lines in a portfolio, and Scalable's own app uses it.
    public static var holdings: String { pick("Holdings", "Positionen") }
    public static var back: String { pick("Back", "Zurück") }

    public static var readingHoldings: String {
        pick("Reading your positions…", "Positionen werden gelesen…")
    }
    public static var cantReadHoldings: String {
        pick("Can't read your positions", "Positionen nicht lesbar")
    }
    public static var noHoldings: String { pick("No positions", "Keine Positionen") }
    public static var noHoldingsMessage: String {
        pick(
            "The broker reports no positions in this portfolio yet.",
            "Der Broker meldet für dieses Portfolio noch keine Positionen."
        )
    }

    /// Marks figures behind a quote the broker itself flagged as stale.
    public static var quoteOutdated: String {
        pick("Some quotes are stale", "Einige Kurse sind veraltet")
    }

    // MARK: - Holdings · time contribution

    public static var whatBoughtYouTime: String {
        pick("What bought you time", "Was Zeit gebracht hat")
    }

    /// The hero's two labels, under the two years.
    public static var yours: String { pick("yours", "mit Gewinn") }
    public static var withoutGains: String { pick("without gains", "ohne Gewinn") }

    /// Stands in for the second year when the goal is never reached without the
    /// gains, which is a stronger statement than any date.
    public static var withoutGainsNever: String {
        pick("out of reach", "unerreichbar")
    }

    /// Names the page's one composition mark.
    public static var theWholePortfolio: String {
        pick("What you hold", "Was du hältst")
    }

    /// The hero when the gains do not move the arrival *year* — the ordinary case,
    /// since a few thousand euros against a six-figure goal is weeks, not years.
    ///
    /// Said plainly rather than dressed up: printing the same year twice with an
    /// arrow between them would claim the gains changed nothing, and inventing month
    /// precision to force a visible difference would claim the projection is sharper
    /// than it is.
    /// Deliberately without the number: the line directly beneath carries the weeks
    /// and the euros, and stating the weeks here too put the same figure twice in
    /// adjacent lines — once as "later", once as "earlier".
    public static var sameYearWithoutGains: String {
        pick("Without your gains, the same year.", "Ohne deine Gewinne dasselbe Jahr.")
    }

    /// The hero when they do move it.
    public static func withoutGainsYear(_ year: Int) -> String {
        pick("Without your gains: \(year)", "Ohne deine Gewinne: \(year)")
    }

    /// The hero unit. Weeks rather than months because the numbers are small: a
    /// gain worth 0.4 months reads as nothing, the same gain as two weeks reads as
    /// something.
    public static func weeksEarlier(_ weeks: String) -> String {
        pick("\(weeks) weeks earlier", "\(weeks) Wochen früher")
    }
    public static func weeksLater(_ weeks: String) -> String {
        pick("\(weeks) weeks later", "\(weeks) Wochen später")
    }
    public static var weeksAbbreviated: String { pick("wk", "Wo.") }

    /// Says out loud what the hero figure is, so the number is not mistaken for a
    /// return.
    public static func gainsInGoalTime(_ gain: String) -> String {
        pick(
            "Your \(gain) of gains, as arrival date.",
            "Dein Gewinn von \(gain), als Zieldatum."
        )
    }

    /// Shown in place of a bar when the goal is not reached without that position.
    public static var withoutItNoArrival: String {
        pick("carries the goal", "trägt das Ziel")
    }

    public static var noArrivalToMove: String {
        pick(
            "No projected arrival to move, so there is no time to attribute.",
            "Ohne Prognose gibt es keine Zeit, die sich zuordnen ließe."
        )
    }

    // MARK: - Holdings · cost basis

    public static var yourMoneyAndTheMarkets: String {
        pick("Your money · the market's", "Dein Geld · das des Marktes")
    }
    public static func paidIn(_ amount: String) -> String {
        pick("Paid in \(amount)", "Eingezahlt \(amount)")
    }
    public static func earned(_ amount: String) -> String {
        pick("Earned \(amount)", "Erwirtschaftet \(amount)")
    }

    // MARK: - Holdings · since buy

    public static var sinceYouBought: String { pick("Since you bought", "Seit dem Kauf") }
    public static func portfolioAt(_ percent: String) -> String {
        pick("portfolio \(percent)", "Portfolio \(percent)")
    }

}
