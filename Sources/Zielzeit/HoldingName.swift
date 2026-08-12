import SwiftUI
import ZielzeitCore

// Turning the broker's instrument names into something readable.

enum HoldingName {

    /// Trims the issuer and the share-class suffix from a fund's legal name.
    ///
    /// A 344pt row cannot hold "iShares MSCI Emerging Markets IMI Screened (Acc)",
    /// and truncating it leaves five rows that all begin "iShares MSCI…" and differ
    /// only past the ellipsis. Dropping the parts that repeat is what makes the list
    /// scannable — the ISIN is what identifies a position exactly, and it is on the
    /// row's tooltip rather than in the name.
    static func short(_ name: String) -> String {
        var trimmed = name

        // Repeatedly, not once: "iShares MSCI Europe Screened" carries two of these
        // back to back, and stripping only the first leaves every row in the legend
        // starting "MSCI …" — which was the problem.
        var strippedSomething = true
        while strippedSomething {
            strippedSomething = false
            for prefix in issuers where trimmed.hasPrefix(prefix + " ") {
                trimmed.removeFirst(prefix.count + 1)
                strippedSomething = true
                break
            }
        }

        for suffix in shareClasses where trimmed.hasSuffix(suffix) {
            trimmed.removeLast(suffix.count)
            break
        }

        // Never returns nothing: a fund named exactly after its issuer would
        // otherwise reduce to an empty row.
        let short = trimmed.trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? name : short
    }

    /// Issuers common enough on a Scalable portfolio to be noise in a list of it.
    /// Not exhaustive by design: an unrecognised issuer keeps its name in full,
    /// which is worse-looking but never wrong.
    ///
    /// `MSCI` is in here for the same reason and not because it is an issuer: on a
    /// portfolio of broad index funds nearly every name starts with it, so in a
    /// two-column legend it is the word that pushes the part you need — Europe,
    /// Emerging Markets — out past the ellipsis. `FTSE` and `S&P` stay, because
    /// there they are the distinguishing part of the name rather than the prefix
    /// every row shares.
    private static let issuers = [
        "iShares", "Vanguard", "Invesco", "Xtrackers", "Amundi", "SPDR", "HSBC", "Franklin",
        "VanEck", "MSCI",
    ]

    private static let shareClasses = [" (Acc)", " (Dist)", " Acc", " Dist"]
}
