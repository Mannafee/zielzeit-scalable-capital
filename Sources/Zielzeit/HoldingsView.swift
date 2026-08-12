import SwiftUI
import ZielzeitCore

/// The holdings page: three readings of the same positions.
///
/// Ordered by what the app is for. Time first, because that is the unit the whole app
/// converts money into; then what the money is; then how each part of it has done.
///
/// It was five readings for a while. A diversification panel and the broker's stress
/// scenarios were cut for answering questions this app does not ask, and a
/// what-a-crash-costs panel that replaced them went too — three sections that each
/// say something is worth more than five where two are filler.
struct HoldingsView: View {

    let state: HoldingsState
    /// Why the last refresh failed, while the figures below are the last good ones.
    var staleReason: String?

    /// How much room the pager is giving this page — the height of the page beside
    /// it, so both are the same size and swiping between them does not resize the
    /// popover. `nil` when there is no pager, in which case the page takes what it
    /// needs up to the screen's limit.
    var availableHeight: CGFloat?

    let onBack: () -> Void
    let onRetry: () -> Void

    @Environment(\.isRasterizing) private var isRasterizing

    /// The scrolling content's full height, so the fade at the bottom edge appears
    /// only when there is actually something below it.
    @State private var contentHeight: CGFloat = 0

    /// How many points of page remain below the fold. Drives the chevron, which has
    /// to disappear once there is nothing left to scroll to — a permanent "more
    /// below" arrow at the end of a page is a lie about the page.
    @State private var distanceBelow: CGFloat = 0

    /// How tall the scrolling part may get.
    ///
    /// Matches the projection page when the pager offers a height, so the two pages
    /// are one size. Anything that does not fit scrolls — which, now that the page is
    /// three sections rather than five, is usually nothing.
    ///
    /// The fallback is the display: a popover taller than the screen does not scroll,
    /// AppKit clips it, and what it clips is the top, where the only way back is.
    /// Bounded at both ends, so a very tall display does not produce a popover the
    /// length of the screen and a very short one still gets a usable page.
    private var maxContentHeight: CGFloat {
        if let availableHeight {
            // What is left after this page's own header and the gap beneath it.
            return max(availableHeight - Self.headerAllowance, 240)
        }
        let chrome: CGFloat = 150
        let available = (NSScreen.main?.visibleFrame.height ?? 800) - chrome
        return min(max(available, 320), 720)
    }

    /// The header row plus the spacing under it, which the scrolling area does not
    /// get. Measured rather than guessed would be better; it is a constant because
    /// the header is one line of fixed type and has been since it was written.
    private static let headerAllowance: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Outside the scroll view on purpose: the back arrow has to stay
            // reachable no matter how far down the page you are.
            header

            if isRasterizing {
                // `--render` only: laid out at full height so the whole page lands
                // in the PNG. See `EnvironmentValues.isRasterizing`.
                VStack(alignment: .leading, spacing: 14) {
                    sections
                }
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 14) {
                        sections
                    }
                    // Keeps the last section clear of the seam above the footer.
                    .padding(.bottom, 2)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        contentHeight = height
                    }
                }
                .frame(maxHeight: maxContentHeight)
                // No rubber-banding on a page that already fits.
                .scrollBounceBehavior(.basedOnSize)
                // `.never`, not `.hidden`: with "Show scroll bars" left on Automatic
                // and a mouse attached, macOS draws the permanent legacy scroller —
                // fifteen points of chrome down the side of a popover that is only
                // 344 wide. The fade and the chevron below say "there is more"
                // instead, which is the only job the bar was doing here.
                .scrollIndicators(.never)
                .mask(bottomFade)
                // How much is still below, so the cue can appear only while there is
                // somewhere to go and get out of the way at the end of the page.
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentSize.height
                        - (geometry.contentOffset.y + geometry.containerSize.height)
                } action: { _, remaining in
                    distanceBelow = remaining
                }
                .overlay(alignment: .bottom) { moreBelowCue }
            }
        }
        // The popover's parent measures its ideal width while rasterizing. German
        // labels are wider than English, so pinning the real content width here keeps
        // one long row from expanding the page and being cropped on both sides.
        .frame(width: Theme.popoverWidth - (Theme.gutter * 2), alignment: .leading)
    }

    @ViewBuilder
    private var sections: some View {
        Group {
            switch state {
            case .ready(let report) where report.isEmpty:
                EmptyStateView(
                    symbol: "tray",
                    title: Strings.noHoldings,
                    message: Strings.noHoldingsMessage,
                    actionTitle: Strings.tryAgain,
                    action: onRetry
                )
            case .ready(let report):
                HoldingsHeroCard(report: report)
                PortfolioOverviewCard(holdings: report.holdings)
                PositionImpactSection(report: report)
                PortfolioInsight(report: report)

                if report.holdings.hasOutdatedQuote {
                    note(Strings.quoteOutdated, symbol: "clock.arrow.circlepath")
                }
                if let staleReason {
                    note(Strings.couldNotUpdate(staleReason), symbol: "exclamationmark.triangle.fill")
                }
            case .loading, .idle:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(Strings.readingHoldings)
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            case .failure(let message):
                EmptyStateView(
                    symbol: "exclamationmark.triangle",
                    title: Strings.cantReadHoldings,
                    message: message,
                    actionTitle: Strings.tryAgain,
                    action: onRetry,
                    tint: .orange
                )
            }
        }
    }

    /// The back arrow and the page's name. The arrow is the only way out, so it is
    /// a real target rather than a glyph beside the title.
    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(FooterButtonStyle())
            .help(Strings.back)

            Text(Strings.holdings)
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            if case .ready(let report) = state {
                // To the cent, like the popover's own Portfolio row. This is the
                // figure a reader checks against their broker, and whole euros put
                // it up to fifty cents away from both — the same portfolio read as
                // two different numbers one tap apart.
                Text(Format.euro(report.holdings.total, decimals: 2))
                    .font(Theme.numeric(12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Softens the last few points of the scrolling area, so content passes under an
    /// edge rather than being sliced by one.
    ///
    /// Only when the page overflows: a fade over content that already fits would dim
    /// the last row for no reason. Kept to twelve points and never fully transparent
    /// at the bottom, because `mask` takes hit testing with it and a control in that
    /// strip still has to be clickable.
    private var bottomFade: LinearGradient {
        let overflows = contentHeight > maxContentHeight + 1
        return LinearGradient(
            stops: overflows
                ? [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.93),
                    .init(color: .black.opacity(0.15), location: 1),
                ]
                : [.init(color: .black, location: 0), .init(color: .black, location: 1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A chevron saying the page continues, shown only while it does.
    ///
    /// The fade alone was not enough: a soft edge reads as a design flourish, and the
    /// scroll bar it replaced was the only thing telling anyone the page went further.
    /// This is small, it points, and it goes away — it fades out over the last stretch
    /// rather than at the very end, so it is already gone by the time you arrive
    /// instead of vanishing under the cursor.
    @ViewBuilder
    private var moreBelowCue: some View {
        let visible = min(max(distanceBelow - Self.cueFadeDistance, 0) / Self.cueFadeDistance, 1)
        Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule().fill(.quaternary)
            }
            .opacity(visible)
            .padding(.bottom, 1)
            // Decoration for a gesture, and a duplicate of the scroll position for
            // anyone using VoiceOver, which announces that itself.
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.15), value: visible)
    }

    /// Over how many points the cue fades. Twice this much below the fold and it is
    /// fully opaque; at this much or less it is gone.
    private static let cueFadeDistance: CGFloat = 24

    /// A caveat about the figures above, said once for the page rather than marked
    /// on each row: both of these are about every number here, not about one of them.
    private func note(_ text: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.orange)
    }
}



// Shared with HoldingsCards and HoldingsPositions, which is why it is no longer
// file-private.
extension View {
    func dashboardCard() -> some View {
        background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.quaternary, lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.035), radius: 8, y: 3)
        }
    }
}
