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
                    onEnabledAccess: { model.markAccessEnabled() }
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
        // Localized rows can have an ideal width wider than the popover. Pin the
        // page itself so SwiftUI wraps or compresses those rows instead of centring
        // an oversized tree and clipping both edges.
        .frame(width: Theme.popoverWidth - (Theme.gutter * 2), alignment: .leading)
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

