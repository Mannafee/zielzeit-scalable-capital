import AppKit
import SwiftUI
import ZielzeitCore

// The renders that move: the README's GIF and the site's promo film, plus the
// single-frame capture both are built out of.

extension RenderMode {

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
}
