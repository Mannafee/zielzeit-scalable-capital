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
    case french = "fr"
    case spanish = "es"
    case italian = "it"

    /// The language everything renders in.
    ///
    /// **Defaults to English and is set once at startup**, in `main`, from
    /// `detected`. That direction matters: tests and any other non-app caller get
    /// a deterministic language without having to pin one, and only the app —
    /// which is the only thing with a device to read a preference from — opts in
    /// to detection.
    public static var current: AppLanguage = .english

    /// The language the device asks for, or English when none are supported.
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
        case .french: return "Français"
        case .spanish: return "Español"
        case .italian: return "Italiano"
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
    /// It leads in English and follows the amount in the four continental
    /// European languages. The wrong position makes a translation look unchecked.
    public var currencySymbolLeads: Bool { self == .english }

    /// Whether typography in this language separates a percentage from its sign.
    public var percentSignIsSpaced: Bool { self == .german || self == .french }

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
        case .french: return Locale(identifier: "fr_FR")
        case .spanish: return Locale(identifier: "es_ES")
        case .italian: return Locale(identifier: "it_IT")
        }
    }
}

/// What the reader has chosen in the menu.
///
/// `system` is a real option rather than the absence of a choice: it means
/// "keep following the Mac", so a user who moves their Mac to German gets a
/// German Zielzeit without going back into the menu. Storing the resolved
/// language instead would silently freeze that.
public enum LanguagePreference: String, CaseIterable, Sendable {
    case system
    case english = "en"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case italian = "it"

    /// The language this pins, or `nil` for "whatever the device says".
    public var language: AppLanguage? {
        switch self {
        case .system: return nil
        case .english: return .english
        case .german: return .german
        case .french: return .french
        case .spanish: return .spanish
        case .italian: return .italian
        }
    }

    public init(language: AppLanguage) {
        switch language {
        case .english: self = .english
        case .german: self = .german
        case .french: self = .french
        case .spanish: self = .spanish
        case .italian: self = .italian
        }
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
