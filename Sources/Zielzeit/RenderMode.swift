import AppKit
import SwiftUI
import ZielzeitCore

/// Whether this view tree is being rasterized by `--render` rather than shown in a
/// real popover.
///
/// `ImageRenderer` cannot rasterize AppKit-backed content, and a SwiftUI
/// `ScrollView` is AppKit-backed — a page inside one renders as an empty rectangle.
/// The holdings page reads this to lay itself out at full height for the renderer
/// while scrolling in the app, so `make ui` and `make shots` keep working on the one
/// screen tall enough to need scrolling.
///
/// The only environment flag of its kind, and it should stay that way: it makes what
/// is rendered differ from what ships, which is worth it to keep a page reviewable
/// and worth nothing anywhere else.
private struct RasterizingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isRasterizing: Bool {
        get { self[RasterizingKey.self] }
        set { self[RasterizingKey.self] = newValue }
    }
}

/// `zielzeit --render <path> [state] [--dark]`: rasterize the popover to a PNG.
///
/// A popover cannot be opened from a script without accessibility permission, so
/// this is how the UI gets inspected during development — render it, then look at
/// the image. It also makes it cheap to check both appearances.
@MainActor
enum RenderMode {

    static func run(
        path: String,
        stateName: String,
        dark: Bool,
        provider: PortfolioProviding = ScalableClient(),
        goalStore: GoalStore = GoalStore()
    ) -> Int32 {
        // SwiftUI needs an initialized application before it will rasterize, but
        // must not take over the process, so no `run()` and no activation.
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let model: AppModel
        switch DevState.model(named: stateName, provider: provider, goalStore: goalStore) {
        case .success(let built):
            model = built
        case .failure(let failure):
            complain(failure.message)
            return 1
        }

        let view = PopoverView(model: model, onQuit: {})
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.isRasterizing, true)
            .background(dark ? Color(white: 0.13) : Color(white: 0.97))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        // Semantic colours resolve against the current drawing appearance, so
        // rasterizing has to happen inside the requested one — otherwise both
        // renders come out in whatever the system is set to.
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        var rendered: NSImage?
        if let appearance {
            appearance.performAsCurrentDrawingAppearance { rendered = renderer.nsImage }
        } else {
            rendered = renderer.nsImage
        }

        guard let image = rendered,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            complain("Could not rasterize the view.")
            return 1
        }

        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            complain("Could not write \(path): \(error.localizedDescription)")
            return 1
        }

        print("Rendered \(stateName) (\(dark ? "dark" : "light")) → \(path)  \(Int(image.size.width))×\(Int(image.size.height))pt")
        return 0
    }

    /// `zielzeit --shot <path> [state] [--dark] [--scale N]`: rasterize the popover
    /// *including* its AppKit-backed controls.
    ///
    /// Why this exists alongside `run(path:…)`: `ImageRenderer` cannot draw
    /// NSView-backed controls, so the two sliders and the footer menu come out of
    /// `--render` as flat coloured blocks. Hosting the same view in a real (offscreen)
    /// window and asking AppKit to cache its display draws them properly.
    ///
    /// The scale is not the window's to give: an offscreen window inherits the
    /// backing scale of the display it is on, so on a 1× monitor `cacheDisplay`
    /// would produce a 1× image. Allocating the bitmap at `scale ×` the pixel count
    /// while leaving its `size` in points makes AppKit draw magnified into it, which
    /// is how a Retina asset comes out of a non-Retina Mac.
    ///
    /// One known infidelity, and it is not worth chasing again: **prominent buttons
    /// come out grey**, not in the accent colour, because `cacheDisplay` draws them
    /// unemphasized. Making the window key and activating the app (`.accessory` plus
    /// `activate(ignoringOtherApps:)`) were both tried and changed nothing. Only the
    /// setup screen has one, so `make open` remains the way to see that button in its
    /// real colour.
    static func shot(
        path: String,
        stateName: String,
        dark: Bool,
        scale: Int = 2,
        provider: PortfolioProviding = ScalableClient(),
        goalStore: GoalStore = GoalStore()
    ) -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let model: AppModel
        switch DevState.model(named: stateName, provider: provider, goalStore: goalStore) {
        case .success(let built):
            model = built
        case .failure(let failure):
            complain(failure.message)
            return 1
        }

        // An opaque backdrop, as in `run(path:…)`: the popover's own material is
        // translucent and NSPopover supplies what sits behind it, so capturing the
        // view on its own composites it against nothing and everything washes grey.
        let hosting = NSHostingController(
            rootView: PopoverView(model: model, onQuit: {})
                .background(dark ? Color(white: 0.13) : Color(white: 0.97))
        )
        // The same option the popover itself needs, for the same reason: without it
        // the hosting view keeps a default size and the content is clipped.
        hosting.sizingOptions = [.preferredContentSize]

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hosting.view.fittingSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = .clear
        // Offscreen, so nothing flashes on the user's display, but ordered in —
        // AppKit will not lay out or draw a window that was never shown.
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.makeKeyAndOrderFront(nil)

        // Let layout settle. SwiftUI resolves sizes and Charts build their scales on
        // subsequent runloop turns, so capturing immediately catches a half-laid-out
        // view — reliably visible as a chart with no curves in it.
        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        let view = hosting.view
        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds

        guard bounds.width > 1, bounds.height > 1 else {
            complain("The hosted view has no size; nothing to capture.")
            return 1
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bounds.width) * scale,
            pixelsHigh: Int(bounds.height) * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            complain("Could not allocate a \(scale)× bitmap.")
            return 1
        }
        // Point size against a larger pixel count is what asks for magnification.
        rep.size = bounds.size

        // Semantic colours resolve against the current drawing appearance, exactly
        // as in `run(path:…)`.
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        appearance?.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: bounds, to: rep)
        }

        window.orderOut(nil)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            complain("Could not encode the capture.")
            return 1
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            complain("Could not write \(path): \(error.localizedDescription)")
            return 1
        }

        print("Shot \(stateName) (\(dark ? "dark" : "light")) → \(path)  \(rep.pixelsWide)×\(rep.pixelsHigh)px @\(scale)×")
        return 0
    }

    /// `zielzeit --demo <path> [--dark] [--scale N]`: capture the popover while the
    /// "save more" slider sweeps, and write it as an animated GIF.
    ///
    /// Zielzeit is a motion product and the README could not show it. The two sliders
    /// are the moment the app stops being a number and starts being a tool — a still
    /// of one parked mid-range (`STATE=slider`) shows *that* it moves, not what moving
    /// it does to the year, the sentence and the curves.
    ///
    /// **A fresh window per frame, paying the 1.5s layout settle twenty times over,
    /// and that is the deliberate choice.** Sweeping the slider inside one long-lived
    /// window is far quicker and it gets the curves wrong: SwiftUI animates the chart,
    /// so a capture taken before the transition *finishes* freezes a curve between two
    /// shapes and `cacheDisplay` writes out the zigzag. Waiting long enough per frame
    /// costs most of the saving anyway, and a frame built from scratch is exactly what
    /// `--shot` already produces, so the demo cannot show something the screenshots
    /// would not. Correctness over a build step nobody waits on.
    ///
    /// The loop **ping-pongs** — out to the ceiling and back — so it can play
    /// `.loopCount 0` without the jump-cut a one-way sweep ends on.
    static func demo(path: String, dark: Bool, scale: Int = 2, steps: Int = 10) -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        // Built once purely to read the ceiling the sweep runs to; every frame gets
        // its own.
        guard case .success(let probe) = DevState.model(named: "ready"),
              case .ready(let report) = probe.state else {
            complain("The demo needs a ready report. Pass ZIELZEIT_GOAL and ZIELZEIT_SC_BIN.")
            return 1
        }

        // Out to the ceiling in `steps`, then back, dropping the two turning points
        // so neither end is held for two frames.
        let ceiling = report.extraSavingsCeiling
        let rising = (0...steps).map { ceiling * Double($0) / Double(steps) }
        let values = rising + rising.dropFirst().dropLast().reversed()

        var frames: [CGImage] = []
        for (index, value) in values.enumerated() {
            guard case .success(let model) = DevState.model(named: "ready") else {
                complain("Could not build frame \(index).")
                return 1
            }
            model.extraSavings = value
            guard let frame = capture(model, dark: dark, scale: scale) else {
                complain("Could not capture frame \(index).")
                return 1
            }
            frames.append(frame)
        }

        guard writeGIF(frames, to: URL(fileURLWithPath: path), frameDuration: 0.11) else { return 1 }
        let bytes = (try? FileManager.default
            .attributesOfItem(atPath: path)[.size] as? Int) ?? nil
        print("""
            Wrote \(frames.count) frames → \(path)  \
            \(frames[0].width)×\(frames[0].height)px\
            \(bytes.map { "  \($0 / 1024)KB" } ?? "")
            """)
        return 0
    }

    /// `zielzeit --film <dir> --plates <dir>`: composite every frame of the promo
    /// film from a plate set, as numbered PNGs for ffmpeg to encode.
    ///
    /// Fast, unlike `demo`: there is no window and no layout to settle, because
    /// every pixel of real UI already exists as a plate. That is the whole point
    /// of the split — see `FilmPlates`.
    static func film(directory: String, platesDirectory: String) -> Int32 {
        _ = NSApplication.shared

        guard let plates = FilmArtwork.load(from: platesDirectory) else {
            complain("Could not load the plate set from \(platesDirectory). Run --film-plates first.")
            return 1
        }

        let base = URL(fileURLWithPath: directory)
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        } catch {
            complain("Could not create \(directory): \(error.localizedDescription)")
            return 1
        }

        for index in 0..<FilmTimeline.frameCount {
            guard let rep = FilmArtwork.frame(index, plates: plates),
                  let png = rep.representation(using: .png, properties: [:]) else {
                complain("Could not compose frame \(index).")
                return 1
            }
            let name = String(format: "frame-%04d.png", index)
            do {
                try png.write(to: base.appendingPathComponent(name))
            } catch {
                complain("Could not write \(name): \(error.localizedDescription)")
                return 1
            }
        }

        print("""
            Composed \(FilmTimeline.frameCount) frames → \(directory)  \
            \(Int(FilmArtwork.size.width))×\(Int(FilmArtwork.size.height))px  \
            \(FilmTimeline.duration)s @\(FilmTimeline.fps)fps
            """)
        return 0
    }

    /// Runs the runloop, because SwiftUI resolves layout on subsequent turns and a
    /// capture taken immediately catches a half-laid-out view.
    private static func settle(for seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    /// The same offscreen-window `cacheDisplay` capture `shot(path:…)` makes, as a
    /// `CGImage` and with the window torn down again.
    /// Internal rather than private because `FilmPlates` captures its plate set
    /// through exactly this path: a plate the film composites must be the same
    /// pixels `--shot` and `demo.gif` produce, or the film would show a popover
    /// the screenshots do not.
    static func capture(_ model: AppModel, dark: Bool, scale: Int) -> CGImage? {
        let hosting = NSHostingController(
            rootView: PopoverView(model: model, onQuit: {})
                .background(dark ? Color(white: 0.13) : Color(white: 0.97))
        )
        hosting.sizingOptions = [.preferredContentSize]

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hosting.view.fittingSize),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.contentViewController = hosting
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = .clear
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        // SwiftUI resolves sizes and Charts build their scales on subsequent runloop
        // turns, so capturing immediately catches a half-laid-out view — reliably
        // visible as a chart with no curves in it.
        settle(for: 1.5)

        let view = hosting.view
        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds
        guard bounds.width > 1, bounds.height > 1 else { return nil }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bounds.width) * scale,
            pixelsHigh: Int(bounds.height) * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = bounds.size

        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: bounds, to: rep)
        }
        return rep.cgImage
    }

    /// Encodes an animated GIF with ImageIO rather than shelling out to ffmpeg or
    /// ImageMagick — the same reasoning that keeps Sparkle the only dependency.
    ///
    /// This used to say the docs build needs no ffmpeg at all. `make film` broke
    /// that: ImageIO cannot write h264, and a 25-second GIF of the film would be
    /// larger than the mp4 and worse. So ffmpeg is now a docs-build tool — but
    /// `demo.gif` still does not need it, and nothing under `Sources/` invokes it.
    private static func writeGIF(
        _ frames: [CGImage], to url: URL, frameDuration: TimeInterval
    ) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, "com.compuserve.gif" as CFString, frames.count, nil
        ) else {
            complain("Could not create \(url.lastPathComponent).")
            return false
        }
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
        ] as CFDictionary)
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: frameDuration,
                ],
            ] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            complain("Could not encode \(url.lastPathComponent).")
            return false
        }
        return true
    }

    /// `zielzeit --menubar <path> [--dark] [--scale N]`: draw the status item the way
    /// it appears in the menu bar — ring, caret and year — on a menu bar backdrop.
    ///
    /// A screenshot of the real menu bar is 20pt tall and unusable in documentation
    /// on a non-Retina display. This composes the same `StatusItemIcon` image with
    /// the same title AppKit would draw beside it, at whatever scale is asked for.
    static func menuBar(
        path: String,
        dark: Bool,
        scale: Int = 4,
        progress: Double = 0.17,
        direction: MoveDirection? = .up,
        year: String = "2033"
    ) -> Int32 {
        _ = NSApplication.shared

        guard let rep = menuBarItem(
            dark: dark, scale: scale, progress: progress, direction: direction, year: year
        ) else {
            complain("Could not allocate a \(scale)× bitmap.")
            return 1
        }

        guard let png = rep.representation(using: .png, properties: [:]) else {
            complain("Could not encode the menu bar image.")
            return 1
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            complain("Could not write \(path): \(error.localizedDescription)")
            return 1
        }
        print("Rendered menu bar item (\(dark ? "dark" : "light")) → \(path)  \(rep.pixelsWide)×\(rep.pixelsHigh)px @\(scale)×")
        return 0
    }

    /// The status item as the menu bar draws it — ring, caret and year on a menu bar
    /// backdrop — magnified `scale` times.
    ///
    /// Shared with the social card rather than drawn twice: the pill is the app's
    /// public face and two copies of these metrics would drift.
    static func menuBarItem(
        dark: Bool,
        scale: Int,
        progress: Double = 0.17,
        direction: MoveDirection? = .up,
        year: String = "2033"
    ) -> NSBitmapImageRep? {
        let icon = StatusItemIcon.ring(
            progress: progress, direction: direction, style: .brand, isDarkBar: dark
        )
        // The menu bar's own metrics: 22pt tall, a few points of padding either side
        // and a small gap between the image and the title.
        let barHeight: CGFloat = 22
        let padding: CGFloat = 6
        let gap: CGFloat = 3
        let font = NSFont.menuBarFont(ofSize: 0)
        let ink = dark ? NSColor.white : NSColor.black
        let title = NSAttributedString(string: year, attributes: [
            .font: font, .foregroundColor: ink,
        ])
        let titleSize = title.size()
        let width = padding + icon.size.width + gap + titleSize.width + padding

        let factor = CGFloat(scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(width * factor),
            pixelsHigh: Int(barHeight * factor),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        rep.size = NSSize(width: width, height: barHeight)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high

        (dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
        NSRect(x: 0, y: 0, width: width, height: barHeight).fill()

        icon.draw(in: NSRect(
            x: padding,
            y: (barHeight - icon.size.height) / 2,
            width: icon.size.width,
            height: icon.size.height
        ))
        title.draw(at: NSPoint(
            x: padding + icon.size.width + gap,
            y: (barHeight - titleSize.height) / 2
        ))

        NSGraphicsContext.restoreGraphicsState()

        return rep
    }

    /// `zielzeit --social <path>`: draw the 1280×640 GitHub social preview card.
    ///
    /// The card is what every unfurl of the repository URL shows — Reddit, Hacker
    /// News, Slack, Mastodon, LinkedIn — and GitHub's automatic one is a generic
    /// avatar-and-description strip. There is no API for uploading it, so this only
    /// writes the file; Settings → Social preview takes it.
    static func socialCard(path: String, scale: Int = 3) -> Int32 {
        _ = NSApplication.shared

        guard let rep = SocialCardArtwork.rep(supersample: scale),
              let png = rep.representation(using: .png, properties: [:]) else {
            complain("Could not render the social card.")
            return 1
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            complain("Could not write \(path): \(error.localizedDescription)")
            return 1
        }

        // GitHub rejects anything over 1MB, and the failure is a silent fall back to
        // the automatic card, so the budget is stated rather than assumed.
        let kilobytes = png.count / 1024
        print("""
            Rendered social preview card → \(path)  \
            \(rep.pixelsWide)×\(rep.pixelsHigh)px, drawn at \(scale)×  \(kilobytes)KB\
            \(png.count > 1_000_000 ? "  ⚠︎ over GitHub's 1MB limit" : " of GitHub's 1024KB limit")
            """)
        return 0
    }

    /// `zielzeit --icons <path>`: draw the menu bar glyph at a range of progress
    /// values, magnified, so the icon design can be judged.
    ///
    /// A 15pt template image is too small to evaluate in a screenshot of the real
    /// menu bar, and the states either side of the current one (empty, complete,
    /// error) never appear on demand.
    static func icons(path: String, dark: Bool, style: StatusItemIcon.Style = .brand) -> Int32 {
        _ = NSApplication.shared

        func ring(_ progress: Double, _ direction: MoveDirection? = nil) -> NSImage {
            StatusItemIcon.ring(progress: progress, direction: direction, style: style, isDarkBar: dark)
        }

        let samples: [(String, NSImage)] = [
            ("0%", ring(0)),
            ("2%", ring(0.02)),
            ("12%", ring(0.12)),
            ("24%", ring(0.24)),
            ("75%", ring(0.75)),
            ("100%", ring(1)),
            // The caret is judged here for the same reason the digits are: at 20pt
            // in a real menu bar, magnification blur makes a clean glyph look like
            // it collides with the ring.
            ("12% up", ring(0.12, .up)),
            ("12% down", ring(0.12, .down)),
            ("12% flat", ring(0.12, .flat)),
            ("unset", StatusItemIcon.unset()),
            ("error", StatusItemIcon.warning()),
        ]

        let scale: CGFloat = 6
        // Wide enough for the ring plus its caret, so the two carets do not spill
        // into the neighbouring cell.
        let cell = CGSize(width: 30 * scale, height: 26 * scale)
        let canvas = NSSize(width: cell.width * CGFloat(samples.count), height: cell.height + 22)

        let output = NSImage(size: canvas)
        output.lockFocus()

        // Template images are tinted by their context, so paint the same
        // backdrop the menu bar would provide.
        (dark ? NSColor(white: 0.15, alpha: 1) : NSColor(white: 0.92, alpha: 1)).setFill()
        NSRect(origin: .zero, size: canvas).fill()

        let ink = dark ? NSColor.white : NSColor.black

        for (index, sample) in samples.enumerated() {
            let origin = CGPoint(x: cell.width * CGFloat(index), y: 22)
            let box = NSRect(
                x: origin.x + (cell.width - sample.1.size.width * scale) / 2,
                y: origin.y + (cell.height - sample.1.size.height * scale) / 2,
                width: sample.1.size.width * scale,
                height: sample.1.size.height * scale
            )

            // Tint inside a transparent image, then composite. Tinting directly
            // onto the opaque backdrop would lose the glyph's alpha (sourceAtop
            // keys off destination alpha, which is 1 everywhere) and fill the
            // whole cell.
            if sample.1.isTemplate {
                tinted(sample.1, with: ink, size: box.size).draw(in: box)
            } else {
                // Colour images are drawn as-is; tinting would flatten them.
                sample.1.draw(in: box)
            }

            let label = NSAttributedString(
                string: sample.0,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: ink.withAlphaComponent(0.7),
                ]
            )
            label.draw(at: NSPoint(x: origin.x + 8, y: 4))
        }

        output.unlockFocus()

        guard let tiff = output.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            complain("Could not rasterize the icons.")
            return 1
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            complain("Could not write \(path): \(error.localizedDescription)")
            return 1
        }
        print("Rendered menu bar icons (\(dark ? "dark" : "light")) → \(path)")
        // Eyeballing a 6× magnification is unreliable for a 20pt glyph, so state
        // the fit numerically: ratio ≥ 1 means the digits touch the ring.
        for percent in [0, 2, 12, 40, 75, 100] {
            let fit = StatusItemIcon.innerFill(percent: percent)
            print(String(
                format: "  %4d%%  text %@  width %.2fpt / %.2fpt available  ratio %.2f",
                percent, fit.text, fit.width, fit.available, fit.width / fit.available
            ))
        }
        return 0
    }

    /// `zielzeit --appicon <dir>`: write a complete `.iconset` for `iconutil`,
    /// plus a `preview.png` showing the icon at the sizes that matter.
    static func appIcon(directory: String) -> Int32 {
        _ = NSApplication.shared

        let base = URL(fileURLWithPath: directory)
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        } catch {
            complain("Could not create \(directory): \(error.localizedDescription)")
            return 1
        }

        for size in AppIconArtwork.iconSetSizes {
            let pixels = size.points * size.scale
            let suffix = size.scale == 2 ? "@2x" : ""
            let name = "icon_\(size.points)x\(size.points)\(suffix).png"
            guard write(AppIconArtwork.image(pixels: pixels), to: base.appendingPathComponent(name)) else {
                return 1
            }
        }

        // A side-by-side sheet, because an icon has to work at 16pt as well as
        // at 512 and only a comparison shows whether it does.
        guard write(previewSheet(), to: base.appendingPathComponent("preview.png")) else { return 1 }

        print("Wrote \(AppIconArtwork.iconSetSizes.count) sizes + preview.png to \(directory)")
        return 0
    }

    /// The icon at several sizes on one canvas, each drawn at its true pixel size
    /// then magnified, so small-size legibility can be judged honestly.
    private static func previewSheet() -> NSImage {
        let samples = [512, 128, 64, 32, 16]
        let scale: CGFloat = 1
        let cellHeight: CGFloat = 512
        let gap: CGFloat = 24
        let width = samples.reduce(0) { $0 + CGFloat($1) * scale + gap } + gap
        let canvas = NSSize(width: width, height: cellHeight + 40)

        let sheet = NSImage(size: canvas)
        sheet.lockFocus()
        NSColor(white: 0.85, alpha: 1).setFill()
        NSRect(origin: .zero, size: canvas).fill()

        var x = gap
        for pixels in samples {
            let drawn = CGFloat(pixels) * scale
            let box = NSRect(x: x, y: canvas.height - 20 - drawn, width: drawn, height: drawn)
            AppIconArtwork.image(pixels: pixels).draw(in: box)

            let label = NSAttributedString(string: "\(pixels)px", attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.black.withAlphaComponent(0.7),
            ])
            label.draw(at: NSPoint(x: x, y: 6))
            x += drawn + gap
        }
        sheet.unlockFocus()
        return sheet
    }

    private static func write(_ image: NSImage, to url: URL) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            complain("Could not rasterize \(url.lastPathComponent).")
            return false
        }
        do {
            try png.write(to: url)
            return true
        } catch {
            complain("Could not write \(url.path): \(error.localizedDescription)")
            return false
        }
    }

    /// Applies a flat colour to a template image, the way the menu bar does.
    private static func tinted(_ image: NSImage, with color: NSColor, size: NSSize) -> NSImage {
        let output = NSImage(size: size)
        output.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        color.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
        output.unlockFocus()
        return output
    }

    private static func complain(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
