# Security

Zielzeit reads a brokerage account, so "trust me" is not good enough. This page is
what it can do, what it cannot, and how to check both without taking anyone's word
for it.

## Check it yourself, in one command

No toolchain, no account, no build:

```sh
git clone https://github.com/Mannafee/zielzeit-scalable-capital
cd zielzeit-scalable-capital
make audit          # or: Scripts/audit -v
```

`Scripts/audit` searches the source for each claim below and prints what it found.
`-v` shows every search, so a passing run is evidence rather than a green tick.
It runs on every push and pull request as the
[Audit workflow](https://github.com/Mannafee/zielzeit-scalable-capital/actions/workflows/audit.yml),
which is what keeps this page from drifting away from the code.

```
  ✓  broker write commands        none          the only broker verbs are overview, savings-plans, transactions, holdings
  ✓  broker commands enumerated   6             overview, savings-plans, transactions, holdings, whoami, installation-code
  ✓  networking code              none          no URLSession, Network.framework or socket API in the app
  ✓  shell invocation             none          one Process(), run by absolute path with an argument array
  ✓  credential access            none          no Keychain, no token, no read of the CLI's session
  ✓  values stored on disk        3             goal, language, hasRequestedAccess — no figures
  ✓  third-party dependencies     1             Sparkle, the updater — nothing else
```

## What it can do

Run six read-only commands through the official
[Scalable Capital CLI](https://github.com/ScalableCapital/scalable-cli), which you
install and sign in to yourself:

| Command | What it reads |
|---|---|
| `sc broker overview` | Portfolio value and trailing returns |
| `sc broker savings-plans` | Monthly contribution and step-up rate |
| `sc broker transactions` | Deposits and withdrawals over the past year |
| `sc broker holdings` | Each position: quantity, average cost, valuation |
| `sc whoami` | Whether the session works, and your first name |
| `sc installation-code` | The code you email to request beta access |

They are enumerated in `ScalableClient.Command`
([`Sources/ZielzeitCore/ScalableClient.swift`](Sources/ZielzeitCore/ScalableClient.swift)),
every call site passes one of them, and no argument list is built anywhere else.
The CLI is executed directly through `Process`, by absolute path, with an argument
array — no shell, so there is no command string a value could break out of.

## What it cannot do

- **Trade, sell, or move money.** There is no write command in the enum and no code
  path that builds one. The setup also has you sign in with
  `sc login --local-read-only`, which makes the *session itself* read-only, enforced
  by the CLI — so the restriction holds even if you stop trusting this app's word.
- **See your password or 2FA.** It never runs `sc login`. Signing in is an OAuth
  device-code flow you complete in your own Terminal; Zielzeit types the command in
  without executing it, and never reads the session the CLI stores.
- **Send your data anywhere.** The app contains no networking code at all: no
  `URLSession`, no sockets, no analytics, no crash reporter, no account. The only
  outbound traffic is the CLI talking to your broker, exactly as it does from a
  shell — plus Sparkle fetching the update feed, which is a GitHub URL in
  `Info.plist` and carries nothing about you.
- **Keep your figures.** Three values persist, in `com.zielzeit.Zielzeit`: your
  `goal`, your `language`, and `hasRequestedAccess`. No balance, no holdings, no
  transactions, no name. Read them with `defaults read com.zielzeit.Zielzeit` and
  remove them with `make uninstall`.

## What is true and not reassuring

Both of these are real, and listing them is the point — an app that only published
its good properties would deserve less trust, not more.

- **It is not sandboxed, and cannot be.** A sandboxed app may not launch another
  program, and running the CLI is Zielzeit's whole job. It runs with your normal
  user permissions. What limits it is that it is small, open, and readable end to
  end — not an OS boundary.
- **The download is not notarized.** It is ad-hoc signed, so macOS will say Apple
  cannot check it for malicious software. That warning is about the absence of a
  paid Developer ID receipt, not about anything found in the app; Apple has not
  inspected it either way. If you would rather not rely on that, build from source
  — `make run`, about a minute, and a locally built app is never flagged.

It also brings up Terminal through one AppleScript, in `SetupView.swift`, to type
the login command into a window without running it.

## Reporting something

Open a [private security advisory](https://github.com/Mannafee/zielzeit-scalable-capital/security/advisories/new),
or a normal issue if it is not sensitive. This is a small free project with one
maintainer, so there is no bounty and no SLA — but a report that Zielzeit can reach
something on this page's "cannot" list will be treated as the most urgent thing in
the repository.

Vulnerabilities in the Scalable Capital CLI itself belong with
[Scalable Capital](https://github.com/ScalableCapital/scalable-cli), not here.

Supported version: the latest release. Zielzeit updates itself, so there are no
maintained older lines.
