import AppKit
import ZielzeitCore

/// Stage 2 of `make film`: the 750 frames, composited from `FilmPlates`' output.
///
/// **This holds display text, and that is deliberate** — the same licence
/// `SocialCardArtwork` has and for the same reason. The film is baked into a
/// video uploaded once; there is no reader whose language it could follow, so
/// there is nothing for `Strings` to translate it into. English, like the card.
///
/// **Nothing here is ever resampled.** The film is a 2× rendering of a 960×600
/// point screen, so a popover plate captured at `--scale 2` is 688×1324 and is
/// drawn at exactly those pixels. That is why there is no push-in: magnifying a
/// plate would resample it, which reads soft however much resolution is thrown
/// at it — the same trap the README screenshots avoid by publishing every image
/// at exactly twice its displayed width, never a fractional ratio. The film
/// directs attention with a dimming spotlight instead of a zoom.
@MainActor
enum FilmArtwork {

    /// A 2× rendering of a 960×600 point screen. Played in a ~960px lightbox this
    /// is pixel-exact on a Retina display, by the same arithmetic the README
    /// screenshots follow.
    static let size = NSSize(width: 1920, height: 1200)

    /// Menu bar: 22pt at 2×, matching what `RenderMode.menuBarItem` renders into.
    private static let barHeight: CGFloat = 44
    /// The popover hangs from the bar, inset from the right as it does on a real
    /// screen and in the site's own hero.
    private static let popoverTop: CGFloat = barHeight + 16
    private static let popoverRightInset: CGFloat = 88

    // Plate rows worth knowing, in plate pixels from the plate's own top. Read
    // off the capture, not guessed: the year occupies rows 88–157 and the two
    // sliders 750–1024, so with `popoverTop` at 60 both are inside 1200 and the
    // sweep needs no camera move to be readable. The footer (rows 1176+) falls
    // below the bottom edge and stays there — it does on a real screen too.

    // MARK: - Copy
    //
    // Five caption lines, matching the transcript the site's dialog prints beneath
    // the video. Change one and change the other, or the transcript stops being one.
    // The three `end*` constants below are end-card chrome, not captions, and are
    // deliberately not in that transcript.

    private static let titleLine = "When will I actually get there?"
    private static let menuBarLine = "The year, in your menu bar."
    private static let scenariosLine = "Three scenarios. Yours is measured, not assumed."
    private static let sweepLine = "Save more, and watch the year move."
    private static let safetyLine = "Read-only. Nothing leaves your Mac."
    private static let endTitle = "Zielzeit"
    private static let endSub = "free · open source"
    private static let endURL = Project.repositoryDisplay

    // MARK: - Plates

    struct Plates {
        let sweep: [NSImage]
        let barYear: NSImage
    }

    static func load(from directory: String) -> Plates? {
        let base = URL(fileURLWithPath: directory)
        func image(_ name: String) -> NSImage? {
            NSImage(contentsOf: base.appendingPathComponent(name))
        }
        var sweep: [NSImage] = []
        for index in 0..<FilmPlates.sweepCount {
            guard let plate = image(String(format: "popover-%02d.png", index)) else { return nil }
            sweep.append(plate)
        }
        guard let barYear = image("menubar-2033.png") else { return nil }
        return Plates(sweep: sweep, barYear: barYear)
    }
}

extension FilmArtwork {

    static func frame(_ index: Int, plates: Plates) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        // 1:1 — the whole no-resampling rule in one line.
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        // The default for the frame: every plate draw below is 1:1 pixels, so
        // nearest-neighbour is not just acceptable but correct — anything else
        // would blend pixels that should not be blended. `drawPopover` switches
        // to `.high` for its own scope, and only while the popover is actually
        // being scaled during its opening transition.
        NSGraphicsContext.current?.imageInterpolation = .none

        let canvas = NSRect(origin: .zero, size: size)
        let scene = FilmTimeline.scene(atFrame: index)

        drawWallpaper(canvas)

        switch scene {
        case .title:
            dim(canvas, alpha: 0.55)
            caption(titleLine, in: canvas, size: 76, weight: .semibold,
                    alpha: FilmTimeline.fade(atFrame: index, in: 0.5, out: 0.5))

        case .approach:
            // No popover here, deliberately: the cut is title → desktop with
            // just the menu bar → the popover *appearing* in `.popoverOpen`.
            // Drawing it early (via `drawDesktop`, as an earlier draft of this
            // file did) made it visible continuously from this scene through
            // `.menuBar` and into `.popoverOpen`'s own fade-in, so the fade
            // had nothing to fade in from and the popover flickered out and
            // back at that boundary instead.
            drawBar(plates.barYear, canvas: canvas)
            // The spotlight closes on the menu-bar corner instead of a push-in.
            spotlight(canvas, tightness: FilmTimeline.eased(FilmTimeline.progress(atFrame: index)))

        case .menuBar:
            // Same reasoning as `.approach`: bar only, no popover.
            drawBar(plates.barYear, canvas: canvas)
            spotlight(canvas, tightness: 1)
            caption(menuBarLine, in: canvas, size: 54, weight: .medium,
                    alpha: FilmTimeline.fade(atFrame: index, in: 0.4, out: 0.4))

        case .popoverOpen:
            let t = FilmTimeline.eased(FilmTimeline.progress(atFrame: index))
            drawBar(plates.barYear, canvas: canvas)
            // The spotlight releases here, easing tightness 1 → 0 across the
            // scene, and it is drawn *before* the popover, not after. Two
            // reasons, both load-bearing:
            //   - Continuity with `.menuBar`: that scene's last frame calls
            //     `spotlight(tightness: 1)` with the same `target`/`radius`
            //     formula, so this scene's first frame (`t == 0` here) is
            //     pixel-identical to it. The dimming lifts smoothly across
            //     these 3s instead of snapping open in a single frame at the
            //     cut — which is the defect this fixes.
            //   - Draw order: a spotlight that is *revealing* the popover
            //     must not also darken the thing it reveals. Drawing it
            //     first dims only the bar/wallpaper underneath; the popover,
            //     drawn after, is untouched by it and fades in purely via its
            //     own `alpha: t` below, so "the dimming lifts" and "the
            //     popover fades in" read as one gesture rather than the
            //     popover fighting its own reveal.
            spotlight(canvas, tightness: 1 - t)
            // Anchored at its top-right corner and easing 0.96 → 1, as NSPopover
            // does. This is the one place a plate is scaled, and only for ~0.4s of
            // transition where softness is invisible; it lands at exactly 1.0.
            drawPopover(plates.sweep[0], canvas: canvas, scale: 0.96 + 0.04 * t, alpha: t)

        case .chartPan:
            drawDesktop(plates.barYear, plate: plates.sweep[0], canvas: canvas,
                        drift: -60 * FilmTimeline.eased(FilmTimeline.progress(atFrame: index)))
            caption(scenariosLine, in: canvas, size: 46, weight: .medium,
                    alpha: FilmTimeline.fade(atFrame: index, in: 0.4, out: 0.4),
                    at: .bottomLeft)

        case .sweep:
            let plate = plates.sweep[FilmTimeline.sweepPlate(atFrame: index, plateCount: plates.sweep.count)]
            // **The menu bar's year does not move with the slider, and must not.**
            // The app deliberately behaves that way: the slider previews inside the
            // popover only, and `ReportTests` guards it. An earlier version of this
            // scene flipped the bar to a second, hardcoded "2030" plate partway
            // through the sweep, which was wrong twice over — it advertised a
            // feature that does not exist, and since the popover's year moves
            // continuously across 48 plates while a single flip does not, the two
            // numbers on screen disagreed for most of the scene (at frame 497 the
            // popover read 2032 and the bar read 2030). The caption is still true:
            // "watch the year move" is the popover's year, which is the real thing.
            drawDesktop(plates.barYear, plate: plate, canvas: canvas, drift: -60)
            caption(sweepLine, in: canvas, size: 46, weight: .medium,
                    alpha: FilmTimeline.fade(atFrame: index, in: 0.4, out: 0.4),
                    at: .bottomLeft)

        case .safety:
            drawDesktop(plates.barYear, plate: plates.sweep[0], canvas: canvas, drift: -60)
            dim(canvas, alpha: 0.35 * FilmTimeline.fade(atFrame: index, in: 0.5, out: 0.5))
            // `.bottomLeft`, not the default `.centre`: at only a 0.35 dim the
            // chart's curves and dashed goal line are still bright enough that
            // white text crossing them (as `.centre` does here) is illegible.
            // The empty region to the popover's left is clear at every moment
            // of this scene, same as `chartPan`/`sweep`.
            caption(safetyLine, in: canvas, size: 54, weight: .medium,
                    alpha: FilmTimeline.fade(atFrame: index, in: 0.4, out: 0.4),
                    at: .bottomLeft)

        case .endCard:
            dim(canvas, alpha: 0.7)
            drawEndCard(canvas, alpha: FilmTimeline.fade(atFrame: index, in: 0.4, out: 0.0))
        }

        return rep
    }

    // MARK: - Pieces

    /// The same wallpaper vocabulary the site's `.stage` draws in CSS and the
    /// social card draws in AppKit: a bloom top-left, a cool pool bottom-right,
    /// a vignette. Linear rather than radial for the sheen, the choice both the
    /// icon and the card already document.
    private static func drawWallpaper(_ canvas: NSRect) {
        NSGradient(
            starting: NSColor(srgbRed: 0.043, green: 0.169, blue: 0.157, alpha: 1),
            ending: NSColor(srgbRed: 0.047, green: 0.200, blue: 0.255, alpha: 1)
        )?.draw(in: canvas, angle: -65)

        radial(canvas, center: CGPoint(x: canvas.width * 0.14, y: canvas.height * 0.94),
               radius: canvas.width * 0.55,
               inner: Theme.Brand.deep.withAlphaComponent(0.42),
               outer: Theme.Brand.deep.withAlphaComponent(0))
        radial(canvas, center: CGPoint(x: canvas.width * 0.92, y: canvas.height * 0.04),
               radius: canvas.width * 0.5,
               inner: NSColor(srgbRed: 0.05, green: 0.26, blue: 0.34, alpha: 0.55),
               outer: NSColor(srgbRed: 0.05, green: 0.26, blue: 0.34, alpha: 0))
        radial(canvas, center: CGPoint(x: canvas.midX, y: canvas.midY),
               radius: canvas.width * 0.72,
               inner: NSColor.black.withAlphaComponent(0),
               outer: NSColor.black.withAlphaComponent(0.40))
    }

    /// `options` defaults to `[]`, matching `drawWallpaper`'s three calls: a
    /// glow that fades to nothing exactly at `radius`, leaving the canvas past
    /// it to whatever was drawn underneath — that is the wallpaper look and it
    /// must not change. `spotlight` is the one caller that opts into
    /// `.drawsAfterEndLocation`, which keeps painting the *outer* colour for
    /// every point past `radius` instead of leaving them untouched. Without
    /// that, `CGContext.drawRadialGradient` only paints the band between the
    /// start and end circles — everything farther than `radius` from the
    /// target was left at the wallpaper's full brightness, so the "spotlight"
    /// was a dark ring floating over a fully-lit background, backwards from
    /// the intent (dim surround, bright target).
    private static func radial(
        _ canvas: NSRect, center: CGPoint, radius: CGFloat, inner: NSColor, outer: NSColor,
        options: CGGradientDrawingOptions = []
    ) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [inner.cgColor, outer.cgColor] as CFArray,
                locations: [0, 1]
              ) else { return }
        context.saveGState()
        context.clip(to: canvas)
        context.drawRadialGradient(
            gradient, startCenter: center, startRadius: 0,
            endCenter: center, endRadius: radius, options: options
        )
        context.restoreGState()
    }

    private static func drawDesktop(
        _ bar: NSImage, plate: NSImage, canvas: NSRect, drift: CGFloat = 0
    ) {
        drawBar(bar, canvas: canvas)
        drawPopover(plate, canvas: canvas, scale: 1, alpha: 1, drift: drift)
    }

    /// The bar is filled in the item plate's own backdrop colour, so the plate's
    /// padding joins it with no seam — the trick the site's `.stage__bar` uses
    /// with `#2b2b2b`.
    private static func drawBar(_ item: NSImage, canvas: NSRect) {
        NSColor(white: 0.17, alpha: 1).setFill()
        NSRect(x: 0, y: canvas.height - barHeight, width: canvas.width, height: barHeight).fill()

        let itemSize = NSSize(width: item.size.width, height: item.size.height)
        item.draw(in: NSRect(
            x: canvas.width - itemSize.width - 36,
            y: canvas.height - barHeight + (barHeight - itemSize.height) / 2,
            width: itemSize.width, height: itemSize.height
        ))
    }

    private static func drawPopover(
        _ plate: NSImage, canvas: NSRect, scale: CGFloat, alpha: CGFloat, drift: CGFloat = 0
    ) {
        let native = plate.size
        let width = native.width * scale
        let height = native.height * scale
        // AppKit's origin is bottom-left; the popover is placed by its top edge.
        let top = canvas.height - popoverTop + drift
        let box = NSRect(
            x: canvas.width - popoverRightInset - width,
            y: top - height,
            width: width, height: height
        )

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -24),
            blur: 50,
            color: NSColor.black.withAlphaComponent(0.55).cgColor
        )
        // `.none` is right everywhere else in this file — every other draw is
        // pixel-for-pixel — but this call is the one exception: during the
        // opening transition `scale` runs 0.96…1.0, and nearest-neighbour on a
        // non-integer scale shows as ragged, aliased edges on the popover's
        // rounded corners for those few frames. `.high` is scoped to just this
        // draw and only actually costs anything when `scale != 1`; at the final
        // 1.0 landing frame (and every other scene, which always passes 1) it is
        // a plain 1:1 blit regardless of which interpolation mode is set.
        let priorInterpolation = NSGraphicsContext.current?.imageInterpolation
        if scale != 1 {
            NSGraphicsContext.current?.imageInterpolation = .high
        }
        plate.draw(in: box, from: .zero, operation: .sourceOver, fraction: alpha)
        if let priorInterpolation {
            NSGraphicsContext.current?.imageInterpolation = priorInterpolation
        }
        context.restoreGState()
    }

    private static func dim(_ canvas: NSRect, alpha: CGFloat) {
        guard alpha > 0 else { return }
        NSColor.black.withAlphaComponent(alpha).setFill()
        canvas.fill()
    }

    /// Darkens everything but a soft-edged hole over the menu-bar item, closing
    /// from the whole frame down to the corner as `tightness` runs 0 → 1. This is
    /// the substitute for a push-in: attention moves, pixels do not.
    private static func spotlight(_ canvas: NSRect, tightness: CGFloat) {
        let target = CGPoint(x: canvas.width - 140, y: canvas.height - barHeight / 2)
        let radius = canvas.width * (1.1 - 0.86 * tightness)
        radial(canvas, center: target, radius: radius,
               inner: NSColor.black.withAlphaComponent(0),
               outer: NSColor.black.withAlphaComponent(0.62 * tightness),
               options: .drawsAfterEndLocation)
    }

    private enum CaptionPlace { case centre, bottomLeft }

    private static func caption(
        _ text: String, in canvas: NSRect, size fontSize: CGFloat,
        weight: NSFont.Weight, alpha: Double, at place: CaptionPlace = .centre
    ) {
        guard alpha > 0.001 else { return }

        // SF, not the site's Rubik: `site/fonts` ships woff2 only and CoreText
        // cannot load it. SF is also the right face for a film about a Mac app.
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = place == .centre ? .center : .left
        paragraph.lineHeightMultiple = 1.15

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = CGSize(width: 0, height: -3)

        let string = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: NSColor.white.withAlphaComponent(CGFloat(alpha)),
            .paragraphStyle: paragraph,
            .shadow: shadow,
        ])

        let inset: CGFloat = 96
        let box: NSRect
        switch place {
        case .centre:
            let width = canvas.width - inset * 2
            let height = string.boundingRect(
                with: NSSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin]
            ).height
            // The rect is sized to exactly the measured text height, so
            // `.usesLineFragmentOrigin` fills it top-to-bottom with no leftover
            // space either side: centring the *rect* on the canvas is enough to
            // centre the text. (An earlier version of this comment argued the
            // opposite — that the rect's origin had to be pushed up by a further
            // `height` to compensate for top-down layout — and measuring the
            // rendered glyph bounds against the canvas centre showed that
            // "fix" landed the text a whole line height too high. It is the
            // rect *not* matching the content height that causes the top/bottom
            // origin confusion in the first place; here it does match, so the
            // plain centring formula is the correct one.)
            box = NSRect(x: inset, y: (canvas.height - height) / 2, width: width, height: height)
        case .bottomLeft:
            // Left, because the popover is anchored right: the only region empty
            // at every moment of the film. Same constraint the site's play pill has.
            let width = canvas.width * 0.46
            let height = string.boundingRect(
                with: NSSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin]
            ).height
            box = NSRect(x: inset, y: 150, width: width, height: height)
        }
        string.draw(with: box, options: [.usesLineFragmentOrigin])
    }

    private static func drawEndCard(_ canvas: NSRect, alpha: Double) {
        guard alpha > 0.001 else { return }
        let fade = CGFloat(alpha)

        let iconSize: CGFloat = 208
        let icon = AppIconArtwork.image(pixels: Int(iconSize))
        icon.draw(
            in: NSRect(x: canvas.midX - iconSize / 2, y: canvas.midY + 40,
                       width: iconSize, height: iconSize),
            from: .zero, operation: .sourceOver, fraction: fade
        )

        func line(_ text: String, _ fontSize: CGFloat, _ weight: NSFont.Weight,
                  _ opacity: CGFloat, _ y: CGFloat) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let string = NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
                .foregroundColor: NSColor.white.withAlphaComponent(opacity * fade),
                .paragraphStyle: paragraph,
            ])
            string.draw(with: NSRect(x: 0, y: y, width: canvas.width, height: fontSize * 1.6),
                        options: [.usesLineFragmentOrigin])
        }

        line(endTitle, 72, .semibold, 1.0, canvas.midY - 60)
        line(endSub, 34, .regular, 0.78, canvas.midY - 118)
        line(endURL, 26, .regular, 0.5, canvas.midY - 176)
    }
}
