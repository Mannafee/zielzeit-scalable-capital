import Foundation

/// Where Zielzeit itself lives.
///
/// One constant rather than a literal at each use site, because the two uses sit
/// far apart — the film's end card and the footer menu — and a repository that
/// gets renamed would otherwise be fixed in one of them and stay wrong in the
/// other until someone watched the film.
public enum Project {

    public static let repositoryURL = URL(string: "https://github.com/Mannafee/zielzeit-scalable-capital")!

    /// The same address written for a reader rather than for a browser: the film
    /// shows it as text nobody can click, where `https://` is noise.
    public static let repositoryDisplay = "github.com/Mannafee/zielzeit-scalable-capital"
}
