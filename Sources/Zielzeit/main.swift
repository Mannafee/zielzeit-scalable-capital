import AppKit
import ZielzeitCore

// Entry point. Three modes:
//
//   zielzeit                           launch the menu bar app
//   zielzeit --once                    print the report as text and exit
//   zielzeit --render <path> [state]   rasterize the popover to a PNG and exit
//
// Text mode never touches AppKit, which makes it the fast way to check the
// numbers. Render mode exists because a popover cannot be opened from a script
// without accessibility permission, so it is how the UI gets inspected.

let arguments = CommandLine.arguments

// The one place the language is chosen, and before any mode runs so `--once`,
// the render harnesses and the app all speak the same one. `AppLanguage.current`
// defaults to English on purpose: only the app has a stored preference and a
// device to fall back on.
AppLanguage.current = LanguageStore().resolved

/// `--scale N`, shared by the two capture modes.
let scaleArgument: Int? = arguments.firstIndex(of: "--scale")
    .flatMap { arguments.count > $0 + 1 ? Int(arguments[$0 + 1]) : nil }
    .map { max(1, min(8, $0)) }

if arguments.contains("--once") {
    exit(TextMode.run())
}

if let index = arguments.firstIndex(of: "--appicon") {
    guard arguments.count > index + 1 else {
        FileHandle.standardError.write(Data("usage: zielzeit --appicon <iconset-dir>\n".utf8))
        exit(2)
    }
    exit(MainActor.assumeIsolated { RenderMode.appIcon(directory: arguments[index + 1]) })
}

if let index = arguments.firstIndex(of: "--icons") {
    guard arguments.count > index + 1 else {
        FileHandle.standardError.write(Data("usage: zielzeit --icons <path> [--dark]\n".utf8))
        exit(2)
    }
    let style: StatusItemIcon.Style =
        arguments.contains("--plate") ? .plate :
        arguments.contains("--template") ? .template : .brand
    exit(MainActor.assumeIsolated {
        RenderMode.icons(path: arguments[index + 1], dark: arguments.contains("--dark"), style: style)
    })
}

if let index = arguments.firstIndex(of: "--demo") {
    guard arguments.count > index + 1 else {
        FileHandle.standardError.write(Data("usage: zielzeit --demo <path.gif> [--dark] [--scale N]\n".utf8))
        exit(2)
    }
    exit(MainActor.assumeIsolated {
        RenderMode.demo(
            path: arguments[index + 1],
            dark: arguments.contains("--dark"),
            scale: scaleArgument ?? 2
        )
    })
}

if let index = arguments.firstIndex(of: "--social") {
    guard arguments.count > index + 1 else {
        FileHandle.standardError.write(Data("usage: zielzeit --social <path> [--scale N]\n".utf8))
        exit(2)
    }
    exit(MainActor.assumeIsolated {
        RenderMode.socialCard(path: arguments[index + 1], scale: scaleArgument ?? 3)
    })
}

if let index = arguments.firstIndex(of: "--menubar") {
    guard arguments.count > index + 1 else {
        FileHandle.standardError.write(Data("usage: zielzeit --menubar <path> [--dark] [--scale N]\n".utf8))
        exit(2)
    }
    exit(MainActor.assumeIsolated {
        RenderMode.menuBar(
            path: arguments[index + 1],
            dark: arguments.contains("--dark"),
            scale: scaleArgument ?? 4
        )
    })
}

if let index = arguments.firstIndex(of: "--film-plates") {
    guard arguments.count > index + 1 else {
        FileHandle.standardError.write(Data("usage: zielzeit --film-plates <dir> [--scale N]\n".utf8))
        exit(2)
    }
    exit(MainActor.assumeIsolated {
        FilmPlates.capture(into: arguments[index + 1], dark: true, scale: scaleArgument ?? 2)
    })
}

// `--film-plates` is tested for above `--film`, because `firstIndex(of: "--film")`
// does not match `--film-plates` (they are separate argv elements, so there is no
// prefix collision) — but keeping the order matches how a reader scans the file.
if let index = arguments.firstIndex(of: "--film") {
    let plates = arguments.firstIndex(of: "--plates")
        .flatMap { arguments.count > $0 + 1 ? arguments[$0 + 1] : nil }
    guard arguments.count > index + 1, let plates else {
        FileHandle.standardError.write(Data("usage: zielzeit --film <frames-dir> --plates <plates-dir>\n".utf8))
        exit(2)
    }
    exit(MainActor.assumeIsolated {
        RenderMode.film(directory: arguments[index + 1], platesDirectory: plates)
    })
}

if let index = arguments.firstIndex(of: "--shot") {
    guard arguments.count > index + 1 else {
        FileHandle.standardError.write(Data("usage: zielzeit --shot <path> [state] [--dark] [--scale N]\n".utf8))
        exit(2)
    }
    let path = arguments[index + 1]
    let state = arguments.count > index + 2 && !arguments[index + 2].hasPrefix("--")
        ? arguments[index + 2]
        : "ready"
    exit(MainActor.assumeIsolated {
        RenderMode.shot(path: path, stateName: state, dark: arguments.contains("--dark"), scale: scaleArgument ?? 2)
    })
}

if let index = arguments.firstIndex(of: "--render") {
    guard arguments.count > index + 1 else {
        FileHandle.standardError.write(Data("usage: zielzeit --render <path> [state] [--dark] [--scale N]\n".utf8))
        exit(2)
    }
    let path = arguments[index + 1]
    let state = arguments.count > index + 2 && !arguments[index + 2].hasPrefix("--")
        ? arguments[index + 2]
        : "ready"
    exit(MainActor.assumeIsolated {
        RenderMode.run(
            path: path,
            stateName: state,
            dark: arguments.contains("--dark"),
            scale: scaleArgument ?? 2
        )
    })
}

let controller = MainActor.assumeIsolated { () -> StatusItemController in
    // `--open [state]` presents the popover on launch, optionally in a named
    // state, so the real UI can be screenshotted during development.
    guard let index = arguments.firstIndex(of: "--open") else {
        // Only here: every capture and text mode has already exited above, so
        // this is the one path that is a real, long-running app. `--open` is
        // deliberately excluded below — it is a development harness, usually
        // pinned to a DevState, and it should not replace the binary out from
        // under a screenshot.
        UpdateController.start()
        return StatusItemController()
    }

    let stateName = arguments.count > index + 1 && !arguments[index + 1].hasPrefix("--")
        ? arguments[index + 1]
        : nil

    var model: AppModel?
    if let stateName {
        switch DevState.model(named: stateName) {
        case .success(let built):
            model = built
        case .failure(let failure):
            FileHandle.standardError.write(Data((failure.message + "\n").utf8))
            exit(1)
        }
    }

    let controller = StatusItemController(model: model)
    controller.opensOnLaunch = true
    return controller
}
let app = NSApplication.shared
app.delegate = controller
// Menu bar only: no Dock icon and no main window.
app.setActivationPolicy(.accessory)
app.run()
