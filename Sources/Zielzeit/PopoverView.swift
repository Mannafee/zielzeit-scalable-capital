import SwiftUI
import ZielzeitCore

/// The popover: everything the app shows, assembled.
struct PopoverView: View {

    @Bindable var model: AppModel
    var onQuit: () -> Void = { NSApp.terminate(nil) }

    /// Each page's natural height, measured as it lays out. The popover follows the
    /// settled page's, so neither page has to wear the other's size.
    @State private var pageHeights: [PopoverPage: CGFloat] = [:]

    /// The page the pager has come to rest on. Bound to the scroll position, so it
    /// tracks a swipe and, written to, performs one.
    @State private var settledPage: PopoverPage?

    @Environment(\.isRasterizing) private var isRasterizing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isPaging {
                pager
            } else {
                content
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 14)
            }

            Spacer(minLength: 12)

            // Gated on there *being* a second page rather than on the pager being
            // active, so `--render` shows the indicator too. It draws no scroll view
            // of its own, and a rasterized page without it would misrepresent what
            // ships.
            if hasTwoPages {
                PageTabs(pages: PopoverPage.allCases, current: model.page) { model.openPage($0) }
                    .padding(.bottom, 6)
            }

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

    /// Whether the two pages are side by side and swipeable.
    ///
    /// Only when there is a second page to swipe *to*: the setup, loading and error
    /// screens have no positions behind them, and a pager over a single page is a
    /// gesture that goes nowhere plus a row of dots that says nothing. The goal
    /// editor is excluded for a different reason — it replaces the popover's whole
    /// content, and swiping out of a half-typed amount would lose it.
    ///
    /// Also off while rasterizing: `ImageRenderer` cannot draw a `ScrollView`, so
    /// `--render` shows the page on its own. See `EnvironmentValues.isRasterizing`.
    private var isPaging: Bool { hasTwoPages && !isRasterizing }

    /// Whether there are two pages at all — which decides the indicator, whether or
    /// not the gesture that goes with it is available.
    private var hasTwoPages: Bool {
        model.canShowHoldings && !model.isEditingGoal
    }

    /// The two pages, side by side, snapping one page at a time.
    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                pageBody(.projection) {
                    if case .ready(let report) = model.state { readyContent(report) }
                }
                pageBody(.holdings) { holdingsContent(availableHeight: pageHeights[.projection]) }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $settledPage)
        // `.never`, not `.hidden`: hidden still yields to "Always show scroll bars"
        // in System Settings, which put a scroller across the bottom of the popover.
        // The dots say which page you are on, so the bar has nothing left to add.
        //
        // Scoped to the horizontal axis on purpose — this modifier reaches every
        // scroll view below it through the environment, and an unscoped `.never`
        // would also strip the holdings page's vertical indicator, which is the only
        // hint that the page continues past the fold.
        .scrollIndicators(.never, axes: .horizontal)
        // Both pages wear the projection's height, so swiping slides sideways
        // without the popover growing or shrinking under the cursor. The projection
        // sets the size because it is the page that opens and the one with a fixed
        // amount to say; the positions page scrolls whatever does not fit, which
        // since it was cut to three sections is usually nothing.
        //
        // `nil` until the first measurement arrives, which lets the popover size
        // itself normally on the very first layout rather than collapsing to nothing.
        .frame(height: pageHeights[.projection])
        // The projection's own height still changes — the sliders come and go with
        // the state — so this animates that, not a change of page.
        .animation(.snappy(duration: 0.28), value: pageHeights[.projection])
        .onAppear { settledPage = model.page }
        // Two-way, and guarded on both sides: the button writes `model.page` and the
        // pager must follow it; a swipe writes `settledPage` and the rest of the
        // popover must follow that. Without the inequality checks these two chase
        // each other.
        .onChange(of: model.page) { _, page in
            guard settledPage != page else { return }
            withAnimation(.snappy(duration: 0.28)) { settledPage = page }
        }
        .onChange(of: settledPage) { _, settled in
            guard let settled, settled != model.page else { return }
            model.openPage(settled)
        }
    }

    /// One page of the pager: exactly the popover's width, measured, and pinned to
    /// the top so a short page does not stretch to a tall one's height.
    private func pageBody<Content: View>(
        _ page: PopoverPage,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            // Takes its ideal height rather than the container's proposal, which is
            // what makes the measurement below the page's *own* height instead of
            // whatever the other page currently forces on it.
            .fixedSize(horizontal: false, vertical: true)
            .containerRelativeFrame(.horizontal)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                pageHeights[page] = height
            }
            .id(page)
            .accessibilityLabel(page.label)
    }

    /// The holdings page, given the height of the page beside it so the two match.
    private func holdingsContent(availableHeight: CGFloat? = nil) -> some View {
        HoldingsView(
            state: model.holdings,
            staleReason: model.holdingsStaleReason,
            availableHeight: availableHeight,
            onBack: { model.closeHoldings() },
            onRetry: { model.loadHoldings() }
        )
        .padding(.bottom, 4)
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
        } else if model.isShowingHoldings {
            // Reached when the pager is off — while rasterizing, or if the
            // projection behind it stopped being readable while the page was open.
            // Ahead of the state switch deliberately: the positions stay up while a
            // background refresh moves `state` underneath them, rather than throwing
            // the reader back on the hour.
            holdingsContent()
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

/// Where you are, and — the part that matters — that there is somewhere else to be.
///
/// Two dots came first and were not enough: a dot says "two of something" and
/// nothing about a gesture, so the second page went unfound. This names both pages,
/// marks the one you are on, and points a chevron at the other in the direction the
/// swipe goes. The names are also targets, so the gesture is an accelerator rather
/// than the only way across.
private struct PageTabs: View {

    let pages: [PopoverPage]
    let current: PopoverPage
    let onSelect: (PopoverPage) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                Button {
                    onSelect(page)
                } label: {
                    label(for: page, at: index)
                }
                .buttonStyle(.plain)
                .help(page.label)
                .accessibilityLabel(page.label)
                .accessibilityAddTraits(page == current ? [.isSelected] : [])
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.2), value: current)
    }

    private func label(for page: PopoverPage, at index: Int) -> some View {
        let isCurrent = page == current
        // The chevron sits on the side the page lies on, so it reads as "that way"
        // rather than as decoration: a page to the right gets a trailing ›, one to
        // the left a leading ‹.
        let isAhead = index > (pages.firstIndex(of: current) ?? 0)

        return HStack(spacing: 3) {
            if !isCurrent, !isAhead {
                Image(systemName: "chevron.left").font(.system(size: 7, weight: .bold))
            }
            Text(page.label)
                .font(.system(size: 10, weight: isCurrent ? .semibold : .regular))
            if !isCurrent, isAhead {
                Image(systemName: "chevron.right").font(.system(size: 7, weight: .bold))
            }
        }
        .foregroundStyle(isCurrent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(isCurrent ? AnyShapeStyle(Theme.accent.opacity(0.12)) : AnyShapeStyle(.clear))
        }
        .contentShape(Capsule())
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
