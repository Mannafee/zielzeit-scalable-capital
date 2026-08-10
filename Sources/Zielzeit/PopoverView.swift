import SwiftUI
import ZielzeitCore

/// The popover: everything the app shows, assembled.
struct PopoverView: View {

    @Bindable var model: AppModel
    var onQuit: () -> Void = { NSApp.terminate(nil) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 14)

            Spacer(minLength: 12)

            Seam()
            FooterView(model: model, onQuit: onQuit)
        }
        .frame(width: Theme.popoverWidth)
        // Every string in the tree below comes from `Strings`, which SwiftUI has
        // nothing to observe. Keying the whole popover on the preference is what
        // rebuilds it when the language changes, rather than leaving half the
        // labels in the language that was current when the view was made.
        .id(model.languagePreference)
        .background {
            // The popover's own material is very translucent, which leaves text
            // competing with whatever wallpaper is behind it. A window-coloured
            // scrim restores contrast while keeping some depth, and a whisper of
            // accent behind the hero gives the card a light source.
            ZStack {
                Rectangle()
                    .fill(.background.opacity(0.55))
                LinearGradient(
                    colors: [Theme.accent.opacity(0.10), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 170)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isEditingGoal {
            GoalEditorView(
                text: $model.goalDraft,
                currentGoal: model.goal,
                onSave: { model.saveGoal($0) },
                onCancel: { model.cancelEditingGoal() }
            )
            .padding(.bottom, 4)
        } else {
            switch model.state {
            case .ready(let report):
                readyContent(report)
            case .setup(let setup):
                SetupView(
                    state: setup,
                    onRecheck: { model.refresh() },
                    onRequestedAccess: { model.markAccessRequested() }
                )
            case .noGoal:
                EmptyStateView(
                    symbol: "target",
                    title: Strings.setAGoal,
                    message: Strings.setAGoalMessage,
                    actionTitle: Strings.setGoal,
                    action: { model.beginEditingGoal() }
                )
            case .loading:
                LoadingView()
            case .failure(let message):
                EmptyStateView(
                    symbol: "exclamationmark.triangle",
                    title: Strings.cantReadPortfolio,
                    message: message,
                    actionTitle: Strings.tryAgain,
                    action: { model.refresh() },
                    tint: .orange
                )
            }
        }
    }

    private func readyContent(_ report: Report) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HeroView(
                report: report,
                preview: heroPreview(report),
                move: model.marketMove(for: report),
                // Withheld when there is only one window: a chip that looks
                // tappable and does nothing is worse than a plain one.
                onCycleWindow: report.availableWindows.count > 1
                    ? { model.cycleMarketWindow(for: report) }
                    : nil
            )

            if !report.isGoalReached {
                ProjectionChartView(report: report, extraSavings: model.extraSavings)
            }

            ScenarioListView(report: report, extraSavings: model.extraSavings)

            if !report.isGoalReached {
                WhatIfSliderView(extraSavings: $model.extraSavings, report: report)

                TargetYearSliderView(targetYear: $model.chosenTargetYear, report: report)
            }

            Seam()

            PortfolioFactsView(report: report)

            DisclaimerView(report: report, initiallyExpanded: model.showsCaveats)
        }
    }

    /// The hero's live projection while the "save more" slider is off zero.
    ///
    /// `nil` at zero rather than an arrival equal to the headline's, so the hero
    /// can tell "not being previewed" from "previewed, and it lands in the same
    /// year" — the first is plain, the second still highlights the figure.
    private func heroPreview(_ report: Report) -> HeroView.Preview? {
        guard model.extraSavings > 0 else { return nil }
        let arrival = report.arrival(extraMonthlySavings: model.extraSavings)
        return HeroView.Preview(months: arrival.months, year: arrival.year)
    }
}

/// The raw numbers, small and secondary — the chart is the headline, these are
/// for when you want to check the arithmetic.
struct PortfolioFactsView: View {

    let report: Report

    var body: some View {
        VStack(spacing: 4) {
            ForEach(report.summaryRows, id: \.kind) { row in
                HStack(spacing: 7) {
                    // Fixed width, and reserved even when a row has no symbol, so
                    // the labels stay in one column whatever the rows are.
                    Image(systemName: symbol(for: row.kind) ?? "circle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(iconTint(for: row.kind))
                        .opacity(symbol(for: row.kind) == nil ? 0 : 1)
                        .frame(width: 13)

                    Text(row.label)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.value)
                        .font(Theme.numeric(11, weight: .medium))
                        .foregroundStyle(tint(for: row.kind))
                }
            }
        }
    }

    /// Symbols are chosen per row rather than carried in `Report`, which holds no
    /// UI. Keyed off `kind` rather than the label, which is translated.
    private func symbol(for kind: Report.SummaryRow.Kind) -> String? {
        switch kind {
        case .portfolio: return "briefcase"
        // The recurring deposit, not an amount — a euro glyph here would just
        // repeat the figure at the other end of the row.
        case .saving: return "repeat"
        case .pastYear:
            return (report.snapshot.oneYearGain ?? 0) >= 0
                ? "chart.line.uptrend.xyaxis"
                : "chart.line.downtrend.xyaxis"
        }
    }

    /// Quiet by default. The past-year row takes its value's colour, so the glyph,
    /// the direction of the line in it and the sign of the number all agree.
    private func iconTint(for kind: Report.SummaryRow.Kind) -> Color {
        kind == .pastYear ? tint(for: kind) : .secondary.opacity(0.55)
    }

    private func tint(for kind: Report.SummaryRow.Kind) -> Color {
        guard kind == .pastYear, let gain = report.snapshot.oneYearGain else {
            return .primary.opacity(0.85)
        }
        return gain >= 0 ? Theme.accent : .red
    }
}

/// Shared empty/error presentation.
struct EmptyStateView: View {

    let symbol: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(.system(size: 15, weight: .semibold))

            Text(message)
                .font(Theme.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .padding(.top, 2)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LoadingView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(Strings.readingPortfolio)
                .font(Theme.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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

            Button {
                model.refresh()
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
                Button { model.refresh() } label: {
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
