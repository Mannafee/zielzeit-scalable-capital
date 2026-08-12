import AppKit
import SwiftUI
import ZielzeitCore

/// Onboarding: install the CLI, get allowlisted, sign in.
///
/// Presented as a numbered checklist rather than a wizard, because the middle
/// step waits on a human at Scalable Capital and the user may come back to this
/// hours later. A checklist survives that; a wizard does not.
struct SetupView: View {

    let state: SetupState
    let onRecheck: () -> Void
    let onRequestedAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch state {
            case .cliMissing:
                installStep(number: 1, isDone: false)
                accessStep(number: 2, code: nil, hasRequested: false, isEnabled: false)
                signInStep(number: 3, isEnabled: false)

            case .notConnected(let code, let hasRequested):
                installStep(number: 1, isDone: true)
                accessStep(number: 2, code: code, hasRequested: hasRequested, isEnabled: true)
                signInStep(number: 3, isEnabled: true)

            case .connected:
                EmptyView()
            }

            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionLabel(text: Strings.connectYourPortfolio)
            Text(state == .cliMissing ? Strings.threeStepsToConnect : Strings.almostThere)
                .font(.system(size: 15, weight: .semibold))
            Text(Strings.setupIntro)
                .font(Theme.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Steps

    private func installStep(number: Int, isDone: Bool) -> some View {
        SetupStep(
            number: number,
            title: Strings.installTheCLI,
            isDone: isDone,
            isEnabled: true
        ) {
            if !isDone {
                VStack(alignment: .leading, spacing: 6) {
                    CopyableCommand(command: AccessRequest.installCommand)
                    Button(Strings.installationInstructions) {
                        NSWorkspace.shared.open(AccessRequest.repositoryURL)
                    }
                    .buttonStyle(.link)
                    .font(Theme.caption)
                }
            }
        }
    }

    private func accessStep(number: Int, code: String?, hasRequested: Bool, isEnabled: Bool) -> some View {
        SetupStep(
            number: number,
            title: hasRequested ? Strings.accessRequested : Strings.requestBetaAccess,
            isDone: hasRequested,
            isEnabled: isEnabled
        ) {
            if isEnabled {
                VStack(alignment: .leading, spacing: 7) {
                    if hasRequested {
                        Text(Strings.willReplyOnceAllowlisted)
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(Strings.sendsYourCodeTo(AccessRequest.emailAddress))
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // The sender address is the one mistake that fails silently,
                    // so it gets a callout rather than a footnote.
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text(AccessRequest.senderNote)
                            .font(Theme.caption)
                            .foregroundStyle(.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

                    if let code {
                        HStack(spacing: 6) {
                            Text(code)
                                .font(Theme.numeric(12, weight: .semibold))
                                .textSelection(.enabled)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.quinary, in: RoundedRectangle(cornerRadius: 5))

                            Button(hasRequested ? Strings.sendAgain : Strings.requestAccess) {
                                if let url = AccessRequest.mailtoURL(installationCode: code) {
                                    NSWorkspace.shared.open(url)
                                }
                                onRequestedAccess()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .controlSize(.small)
                        }
                    } else {
                        Text(Strings.noInstallationCode)
                            .font(Theme.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private func signInStep(number: Int, isEnabled: Bool) -> some View {
        SetupStep(
            number: number,
            title: Strings.signIn,
            isDone: false,
            isEnabled: isEnabled
        ) {
            if isEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Strings.signInExplanation)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    CopyableCommand(command: AccessRequest.loginCommand, opensTerminal: true)
                }
            }
        }
    }

    private var footer: some View {
        Button {
            onRecheck()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                Text(Strings.checkAgain)
            }
            .font(Theme.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.top, 2)
    }
}

/// One numbered step, dimmed until its prerequisites are met.
private struct SetupStep<Detail: View>: View {

    let number: Int
    let title: String
    let isDone: Bool
    let isEnabled: Bool
    @ViewBuilder let detail: Detail

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            badge

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.body.weight(.medium))
                    .foregroundStyle(isEnabled ? .primary : .tertiary)
                detail
            }
        }
        .opacity(isEnabled ? 1 : 0.55)
    }

    private var badge: some View {
        ZStack {
            Circle()
                .fill(isDone ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.quaternary))
                .frame(width: 17, height: 17)

            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text(String(number))
                    .font(Theme.numeric(10, weight: .bold))
                    .foregroundStyle(isEnabled ? .secondary : .tertiary)
            }
        }
    }
}

/// A shell command with a copy button, and optionally a button that opens it in
/// Terminal.
///
/// Opening Terminal *with the command typed but not run* is deliberate: the user
/// presses Return themselves, which keeps the login theirs.
private struct CopyableCommand: View {

    let command: String
    var opensTerminal: Bool = false

    @State private var didCopy = false

    var body: some View {
        // Vertical: a shell command needs the full width or it wraps mid-flag,
        // which makes it unreadable and un-retypeable.
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(command)
                    .font(.system(size: 10.5, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    didCopy = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { didCopy = false }
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(didCopy ? Theme.accent : .secondary)
                .help(Strings.copy)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 5))

            if opensTerminal {
                Button(Strings.openInTerminal) {
                    Terminal.open(typing: command)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

/// Opens Terminal with a command typed in, left for the user to run.
private enum Terminal {

    static func open(typing command: String) {
        // Clipboard first, unconditionally. Sending keystrokes needs an
        // Accessibility grant that Zielzeit has no reason to hold — and which an
        // ad-hoc-signed build loses on every rebuild — so the typing attempt
        // below is the optimistic path, not the reliable one. Copying first means
        // the worst case is "Terminal opens, press ⌘V" rather than an empty
        // window with nothing to paste.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)

        // AppleScript rather than `open -a Terminal`, because the command needs
        // to land in the window without being executed.
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Terminal"
            activate
            if (count of windows) is 0 then
                do script ""
            end if
            set frontWindow to front window
            tell application "System Events" to keystroke "\(escaped)"
        end tell
        """

        guard let script = NSAppleScript(source: source) else { return fallback() }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        // Typing into Terminal needs accessibility permission; if it is not
        // granted, just bring Terminal up — the command is already on the
        // clipboard for the user to paste.
        if error != nil { fallback() }
    }

    private static func fallback() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
