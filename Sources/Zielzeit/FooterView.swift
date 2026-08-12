import SwiftUI
import ZielzeitCore

// The strip along the bottom of the popover: what the figures are stamped with,
// and every control that is not the chart.


/// Last-updated stamp and the controls.
struct FooterView: View {

    let model: AppModel
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // The broker's own as-of time in preference to the fetch time. Outside
            // trading hours these differ by days — a weekend fetch of Friday's close
            // used to be stamped with the minute it was asked for, which claimed a
            // freshness the figures do not have. The fetch time is not lost; it moves
            // to the tooltip, where it answers the different question of whether the
            // app is still running.
            if let valued = model.valuationDate {
                Text(Strings.valued(Format.valuationStamp(valued)))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .help(model.lastFetch.map { Strings.fetched(Format.valuationStamp($0)) } ?? "")
            } else if let lastFetch = model.lastFetch {
                Text(Strings.updated(Format.valuationStamp(lastFetch)))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            // The figures above are the last good ones, kept rather than
            // discarded when a refresh failed. Say so, quietly — and carry the
            // reason in the tooltip rather than the line, which has room for a
            // stamp and little else.
            if let reason = model.staleReason {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .help(Strings.couldNotUpdate(reason))
            }

            Spacer()

            // Only offered when it would work: the page needs a projection to
            // measure its weeks against, so on the setup and error screens there is
            // nothing behind this button and it stays away rather than opening onto
            // an empty page.
            // Withheld while the page is open: the header there already carries the
            // way back, and a button that reopens what you are looking at is a
            // control with nothing to do.
            if model.canShowHoldings, !model.isShowingHoldings {
                Button {
                    model.showHoldings()
                } label: {
                    Image(systemName: "chart.bar.doc.horizontal")
                }
                .buttonStyle(FooterButtonStyle())
                .help(Strings.holdings)
            }

            Button {
                model.refreshVisible()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(FooterButtonStyle())
            .help(Strings.refreshNow)

            Button {
                model.beginEditingGoal()
            } label: {
                Image(systemName: "target")
            }
            .buttonStyle(FooterButtonStyle())
            .help(Strings.setGoal)

            // Icons on every row that does something, and on none of the rows that
            // do not. `Label` is what puts them there: a menu `Button` given one
            // renders symbol-then-title, so the titles stay in a single column and
            // the symbols read as a margin down the left rather than as decoration
            // inside the text.
            //
            // Two rows deliberately have none. The version line is a `Text`, not an
            // action, and an icon would make it look like one; the language rows in
            // the submenu are names of languages, where a repeated globe beside each
            // says nothing the parent row has not already said.
            //
            // The first two reuse the symbols already on the footer buttons an inch
            // to the left — the same action should not be a target here and a
            // crosshair there.
            Menu {
                Button { model.beginEditingGoal() } label: {
                    Label(Strings.setGoalEllipsis, systemImage: "target")
                }
                if model.canShowHoldings, !model.isShowingHoldings {
                    Button { model.showHoldings() } label: {
                        Label(Strings.holdings, systemImage: "chart.bar.doc.horizontal")
                    }
                }
                Button { model.refreshVisible() } label: {
                    Label(Strings.refreshNow, systemImage: "arrow.clockwise")
                }
                // Absent in the capture modes, where no updater is built at all;
                // the version line below is Sparkle-free and still renders.
                if let updates = UpdateController.shared {
                    Button { updates.checkForUpdates() } label: {
                        Label(Strings.checkForUpdates, systemImage: "arrow.down.circle")
                    }
                }
                Text(Strings.versionLine(AppVersion.current))
                // Beside the version line, with the rest of what-this-app-is, and
                // deliberately not in the right-click fallback menu: that one
                // exists so quitting survives a popover that will not render, and
                // an ask has no business on a recovery path.
                Button { NSWorkspace.shared.open(Project.repositoryURL) } label: {
                    Label(Strings.starOnGitHub, systemImage: "star")
                }
                Divider()
                Menu {
                    ForEach(LanguagePreference.allCases, id: \.self) { option in
                        Button(title(for: option)) { model.languagePreference = option }
                    }
                } label: {
                    Label(Strings.language, systemImage: "globe")
                }
                if LaunchAtLogin.isSupported {
                    // The ✓ stays in the title rather than becoming a second symbol:
                    // the leading slot already holds what the row *does*, and the
                    // language rows mark the one in effect exactly this way.
                    Button {
                        try? LaunchAtLogin.toggle()
                    } label: {
                        Label(
                            LaunchAtLogin.isEnabled ? "✓ \(Strings.launchAtLogin)" : Strings.launchAtLogin,
                            systemImage: "power"
                        )
                    }
                }
                Divider()
                Button(action: onQuit) {
                    Label(Strings.quitZielzeit, systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .buttonStyle(FooterButtonStyle())
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    /// A language row, ticked like the launch-at-login item beside it rather than
    /// with a `Picker`: `Menu` here is a plain button list, and one convention for
    /// "this is the one in effect" beats two.
    ///
    /// The languages name themselves — `English`, `Deutsch` — while "System" is
    /// translated, because it is a word about the setting rather than the name of
    /// a language.
    private func title(for option: LanguagePreference) -> String {
        let name = option.language?.endonym ?? Strings.systemLanguage
        return model.languagePreference == option ? "✓ \(name)" : name
    }
}

struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 20)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(configuration.isPressed ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
            }
            .contentShape(Rectangle())
    }
}
