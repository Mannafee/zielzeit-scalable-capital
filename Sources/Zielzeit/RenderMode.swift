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
        scale: Int = 2,
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
        renderer.scale = CGFloat(scale)

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

    // Used by every render entry point, in all three files.
    static func complain(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
