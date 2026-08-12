import AppKit
import SwiftUI
import ZielzeitCore

// The renders that are artwork rather than screenshots: the menu bar item, the
// social card, the icon at every size.

extension RenderMode {

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

}
