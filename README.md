<p align="center">
  <img src="docs/icon.png" alt="The Zielzeit app icon: an emerald progress ring glowing on a dark squircle" width="128">
</p>

<h1 align="center">Zielzeit</h1>

<p align="center">
  <strong>A Scalable Capital portfolio tracker for the macOS menu bar.</strong><br>
  <em>When will my portfolio reach my goal?</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15%2B-black?logo=apple" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <a href="https://github.com/Mannafee/zielzeit-scalable-capital/actions/workflows/ci.yml"><img src="https://github.com/Mannafee/zielzeit-scalable-capital/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
  <a href="https://github.com/Mannafee/zielzeit-scalable-capital/actions/workflows/audit.yml"><img src="https://github.com/Mannafee/zielzeit-scalable-capital/actions/workflows/audit.yml/badge.svg" alt="Audit: the read-only and privacy claims, checked against the source"></a>
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license">
  <img src="https://img.shields.io/badge/broker%20access-read--only-3ECF8E" alt="Read-only broker access">
</p>

<p align="center">
  <!-- The .dmg assets across all releases, counted by GitHub on the way out and
       never by the app. From Scripts/usage-badges, published with the site. -->
  <a href="https://github.com/Mannafee/zielzeit-scalable-capital/releases"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fmannafee.github.io%2Fzielzeit-scalable-capital%2Fbadge%2Fdownloads.json&label=downloads" alt="Total downloads"></a>
</p>

<p align="center">
  <a href="https://github.com/Mannafee/zielzeit-scalable-capital/releases/latest/download/Zielzeit.dmg"><strong>Download</strong></a>
  · <a href="https://mannafee.github.io/zielzeit-scalable-capital/">Website</a>
  · <a href="#install">Homebrew</a>
  · <a href="#build-it-yourself">Build from source</a>
</p>

---

<p align="center">
  <a href="#overview">Overview</a> ·
  <a href="#features">Features</a> ·
  <a href="#safety">Safety</a> ·
  <a href="#install">Install</a> ·
  <a href="#connecting-to-scalable-capital">Setup</a> ·
  <a href="#contributing">Contributing</a>
</p>

> [!IMPORTANT]
> Zielzeit accesses a brokerage account, so the trust boundary is explicit: **six read-only
> commands, no credentials, and no networking code of its own.** Run `make audit` to check those
> claims against the source. See [Safety](#safety) and [SECURITY.md](SECURITY.md).

## Overview

Zielzeit—German for *finish time*—is a free, open-source macOS menu bar app for
[Scalable Capital](https://scalable.capital) investors. It answers one question:
**when will my portfolio reach my goal?**

It reads your broker account through the official
[Scalable Capital CLI](https://github.com/ScalableCapital/scalable-cli). Read-only, with no scraping,
unofficial APIs, or credentials. From your balance, savings plan, deposits, and trailing return, it
projects an arrival year and keeps the answer in your menu bar.

<p align="center">
  <img src="docs/menubar.png" alt="Zielzeit in the macOS menu bar: a 17% progress ring, a green up caret and the projected year 2033" width="298"><br>
  <em>17% of the way there, up on the week, projected to arrive in 2033.</em>
</p>

### Inside the app

<p align="center">
  <img src="docs/popover.png" alt="The Zielzeit projection popover showing the projected year, three scenario curves, two what-if sliders, and portfolio facts" width="344"><br>
  <strong>Your projection at a glance.</strong><br>
  <sub>The arrival year, three scenarios, what-if controls, and portfolio facts in one view.</sub>
</p>

<p align="center">
  <img src="docs/holdings.png" alt="The Zielzeit holdings page: a card reading 21.6 weeks closer to your goal, 2034 without gains against 2033 yours, a portfolio bar with five segments over invested €36 420 and a market gain of €5 930, then each position with its share, return and weeks contributed" width="344"><br>
  <strong>See what your gains bought.</strong><br>
  <sub>Every position is translated into weeks gained or lost on the way to your goal.</sub>
</p>

### Five languages, fully localized

**English · Deutsch · Français · Español · Italiano**

Zielzeit follows the first supported language in your Mac's preferences, or you can switch at any
time from the **Language** menu. Labels, numbers, dates, percentages, and euro placement all follow
the selected language.

<details>
<summary><b>Preview the localized interfaces</b></summary>
<p align="center">
  <img src="docs/popover-de.png" alt="Zielzeit in German" width="190">
  <img src="docs/popover-fr.png" alt="Zielzeit in French" width="190">
  <img src="docs/popover-es.png" alt="Zielzeit in Spanish" width="190">
  <img src="docs/popover-it.png" alt="Zielzeit in Italian" width="190">
</p>
</details>

<sub>Figures in every screenshot are synthetic demo data, not a real account.</sub>

## Features

- **A projected year in your menu bar.** Progress, market direction, and arrival year stay visible
  without another window or tab.
- **Three scenarios on one chart.** Cautious (3%), moderate (6%), and your measured pace use your
  real deposits and [simple Dietz return](https://en.wikipedia.org/wiki/Simple_Dietz_method).
- **Two live what-if sliders.** Add monthly savings to move every projection, or pick a target year
  to calculate the contribution it needs.
- **Inflation in plain sight.** The goal is restated in today's money at the projected horizon.
- **Named market windows.** Cycle through today, this week, this month, three months, six months,
  and the past year.
- **Caveats tied to the figures.** Assumptions quote the exact rate, contribution, and goal on screen.
- **Holdings measured in time.** See what you paid, what the market added, and how many weeks each
  position moved your goal.

## Safety

Zielzeit is read-only against your broker. It can run exactly six commands (`sc broker overview`,
`sc broker savings-plans`, `sc broker transactions`, `sc broker holdings`, `sc whoami` and
`sc installation-code`), enumerated in one Swift type with no other code path. There is no route to
a trade, another write command, or `login`. Nothing leaves your Mac: no analytics, no network call
of its own, and no account of any kind.

Every answer below names the file that backs it, so you can check rather than take it on faith — or
check all of them at once. This needs no Xcode, no account and no build, so you can run it before
you decide whether to download anything:

```sh
git clone https://github.com/Mannafee/zielzeit-scalable-capital
cd zielzeit-scalable-capital
make audit          # add AUDIT_ARGS=-v to see every search and its output
```

```
  ✓  broker write commands        none          the only broker verbs are overview, savings-plans, transactions, holdings
  ✓  broker commands enumerated   6             overview, savings-plans, transactions, holdings, whoami, installation-code
  ✓  networking code              none          no URLSession, Network.framework or socket API in the app
  ✓  shell invocation             none          one Process(), run by absolute path with an argument array
  ✓  credential access            none          no Keychain, no token, no read of the CLI's session
  ✓  values stored on disk        3             goal, language, hasRequestedAccess — no figures
  ✓  third-party dependencies     1             Sparkle, the updater — nothing else
```

`Scripts/audit` searches the source for each claim on this page and prints what it found, and the
[Audit workflow](https://github.com/Mannafee/zielzeit-scalable-capital/actions/workflows/audit.yml)
runs it on every push, so none of this can quietly drift away from the code. Whatever it cannot
check, [`SECURITY.md`](SECURITY.md) states plainly — including the two things that are true and not
reassuring.

<details>
<summary><b>Can Zielzeit trade, sell, or move my money? No.</b></summary>

The six commands above are listed in `ScalableClient.Command`
([`Sources/ZielzeitCore/ScalableClient.swift`](Sources/ZielzeitCore/ScalableClient.swift)) and every
call site passes one of them. There is no code that builds a broker command from anything you type,
and no shell is involved — the CLI is executed directly through `Process`, not through a shell
string that could be made to mean something else.

The setup also asks you to sign in with `sc login --local-read-only`. That flag makes the *session
itself* read-only, enforced by the CLI, so the restriction survives even if you stop trusting this
app's word for it. It is
[Scalable Capital's own flag](https://github.com/ScalableCapital/scalable-cli#quick-start), not
something this project invented — and to quote their documentation rather than paraphrase it, the
guard is local: "This does not change token permissions or backend access." Write commands are
blocked in the CLI until you log in again without the flag.

```sh
grep -A20 'enum Command' Sources/ZielzeitCore/ScalableClient.swift
```

</details>

<details>
<summary><b>Does Zielzeit ever see my Scalable Capital password or 2FA? No.</b></summary>

It never runs `sc login`, and that is deliberate. Signing in is an OAuth device-code flow you
complete yourself in Terminal and in your browser, which is what
[Scalable Capital's own documentation asks for](https://github.com/ScalableCapital/scalable-cli#quick-start):
*"For security and reliability, complete login yourself rather than via an AI agent."* Zielzeit shows
you the command and can open Terminal with it typed but *not* executed. No credential ever passes
through this app, and it never reads the session the CLI stores.

</details>

<details>
<summary><b>Does my portfolio data leave my Mac? No.</b></summary>

It cannot. Zielzeit contains no networking code at all — no `URLSession`, no sockets, no analytics
SDK, no telemetry, no crash reporter, and no account to sign up for. The only outbound traffic on
your machine is the official Scalable CLI talking to your broker, exactly as it does when you run it
yourself in Terminal.

```sh
grep -rn 'URLSession\|import Network\|NWConnection' Sources/   # returns nothing
```
</details>

<details>
<summary><b>What does it store on disk? Three values, and none of them a figure.</b></summary>

Three values in its own preferences domain, `com.zielzeit.Zielzeit`:

| Key | What it is |
|---|---|
| `goal` | Your goal amount, a number |
| `language` | `en`, `de`, `fr`, `es`, `it`, or absent for "follow the Mac" |
| `hasRequestedAccess` | Whether you have emailed for beta access, a true/false |

No balance, no holdings, no transactions, no name. Figures are fetched, shown, and forgotten when
the app quits. Everything it keeps can be read — and deleted — with `defaults`:

```sh
defaults read com.zielzeit.Zielzeit
make uninstall            # removes the app and the saved goal
```
</details>

<details>
<summary><b>Why does macOS say it "cannot be checked for malicious software"? Because it is not notarized.</b></summary>

Because the download is ad-hoc signed but not *notarized*, and notarization requires a paid Apple
Developer account this project does not have. The warning is about the absence of that receipt, not
about anything found in the app — Apple has not inspected it either way.

That is a real limitation and worth weighing. If you would rather not rely on it, build from source;
it is one command and takes under a minute.

```sh
codesign -dv /Applications/Zielzeit.app     # Identifier=com.zielzeit.Zielzeit, Signature=adhoc
```
</details>

<details>
<summary><b>Is it sandboxed? No, and it cannot be.</b></summary>

No, and it cannot be. A sandboxed app cannot launch another program, and Zielzeit's whole job is to
run the Scalable CLI you installed. Being straight about that matters more than the reassurance:
Zielzeit runs with your normal user permissions. What limits it is that it is small, open, and
readable end to end — not an OS boundary.
</details>

<details>
<summary><b>How do I verify all of this myself? <code>make audit</code>, then read the five files it names.</b></summary>

Every claim here is checkable in a few minutes, and the repository is built so it stays that way:

```sh
git clone https://github.com/Mannafee/zielzeit-scalable-capital && cd zielzeit-scalable-capital
make audit AUDIT_ARGS=-v     # every claim above, with the search behind each one
make test && make run        # your build, your machine
```

`make audit` is a shell script (`Scripts/audit`) and short enough to read before you run it, which is
the point: it prints the searches as it goes, so you are checking the source rather than trusting the
script. It reads `Sources/` only — a check that also matched the README would pass on the strength of
the promise instead of the code.

The test suite runs against payloads *shaped* from real CLI responses and never real ones: a CI job
fails the build if anything resembling a real balance, contribution, installation code or ISIN
appears in the repository. That check protects contributors' accounts, and it is also why you can
read every fixture here without seeing anyone's holdings.
</details>

## Requirements

- macOS 15 (Sequoia) or later, on Apple silicon or Intel
- A Scalable Capital brokerage account
- The official Scalable CLI (`sc`), installed with [Homebrew](https://brew.sh), allowlisted by
  Scalable Capital and logged in. The app walks you through all three on first launch.
- Xcode 16 or an equivalent Swift 6 toolchain *(only when building from source)*

## Install

### Homebrew

```sh
brew install --cask mannafee/tap/zielzeit
```

This is the quickest option if you already use Homebrew for the Scalable CLI.

### Disk image

**[Download Zielzeit.dmg](https://github.com/Mannafee/zielzeit-scalable-capital/releases/latest/download/Zielzeit.dmg)**
or browse [all releases](https://github.com/Mannafee/zielzeit-scalable-capital/releases/latest).
The universal build runs on Apple silicon and Intel; Xcode is not required.

1. Open the downloaded `Zielzeit.dmg` and drag Zielzeit onto the Applications folder.
2. Open Zielzeit from Applications. The first launch will be blocked. See below.
3. Look for the progress ring in your menu bar.

Neither install method avoids the first-launch warning below—the app is not notarized. See
[why the Homebrew tap exists and what it does not claim](https://github.com/Mannafee/homebrew-tap).

Zielzeit keeps itself up to date. Later versions install quietly in the background, so this is the
only time you download anything; the new version takes effect the next time you quit and reopen
Zielzeit. The `…` menu in the popover shows which version you are on, and `Check for updates` there
asks immediately if you would rather not wait.

Connecting it to your account then takes two Terminal commands and an email to Scalable Capital,
which is [explained below](#one-time-terminal-setup) and which the app walks you through.

### The first-launch warning is expected

macOS will say Zielzeit "cannot be opened because Apple cannot check it for malicious software."
Nothing is wrong with the download. Zielzeit is signed, but it is not notarized, and notarization
requires a paid Apple Developer account that this free project does not have.

To open it anyway:

> Go to **System Settings → Privacy & Security**, scroll to the bottom, and click **Open Anyway**
> next to the message about Zielzeit. Confirm with Touch ID or your password.

You only do this once. If you would rather not, [build it from source](#build-it-yourself) instead.
A locally built app is never flagged.

### One-time Terminal setup

Zielzeit reads your portfolio through Scalable Capital's official command-line tool, and Scalable
requires that you install it and sign in yourself, so the app is never given your credentials. Even
with the download, there is a one-time setup involving Terminal. Zielzeit walks you through it with
copy buttons for every command, but it is fair to know before you start. See
[Connecting to Scalable Capital](#connecting-to-scalable-capital).

## Build it yourself

Compiling takes about a minute and avoids the Gatekeeper prompt.

```sh
git clone https://github.com/Mannafee/zielzeit-scalable-capital.git
cd zielzeit-scalable-capital
make run          # builds Zielzeit.app, ad-hoc signs it, and launches it
```

To keep it around permanently:

```sh
make install      # copies it to /Applications; needs an admin account
```

> `/Applications` is owned by `root:admin`, so on a standard (non-admin) macOS account `make install`
> fails on the copy. Use `sudo make install`, or just `make run` from the clone. The app works fine
> from anywhere.

`make uninstall` removes the app and the saved goal.

## Connecting to Scalable Capital

The Scalable CLI is in beta and gated: Scalable Capital has to allowlist your machine before it can
log in at all. That is a human round-trip that cannot be automated, so Zielzeit makes every step
around it one tap.

<p align="center">
  <img src="docs/setup.png" alt="Zielzeit's onboarding checklist: install the CLI, request beta access, sign in" width="344">
</p>

<details>
<summary>Auf Deutsch</summary>
<p align="center">
  <img src="docs/setup-de.png" alt="The same onboarding checklist in German: Scalable CLI installieren, Beta-Zugang anfragen, Anmelden" width="344">
</p>
</details>

1. **Install the CLI.** A copy button for `brew tap ScalableCapital/tap && brew install scalable-cli`.
2. **Request beta access.** Zielzeit reads your installation code, and the Request access button
   opens a prefilled email to `cli.beta@scalable.capital`. Nothing to compose.
   ⚠️ **Send it from the email address registered with Scalable Capital.** They match the request to
   your account by sender, and a request from any other address is silently never answered. A
   `mailto:` link opens your default mail account, which often is not that one, so check the From
   field.
3. **Sign in.** Run `sc login --local-read-only` yourself in Terminal. Zielzeit shows the command and
   can open Terminal with it typed but not executed.

Then set your goal. `100000`, `100.000`, `€100 000` and `100k` all parse. German, French,
Spanish, and Italian display continental number formatting with the euro sign after the amount:
`42 350,18 €`.

### Three things Zielzeit will not do

- **Bundle the CLI.** Apache 2.0 would permit it, but Scalable's own guidance is to trust only
  official artifacts, and a broker binary shipped inside a third-party app is what that warns against.
- **Run `sc login`.** It is an OAuth device-code flow and it is yours to complete. The app never sees
  your credentials.
- **Skip `--local-read-only`.** That flag stores the session in locally enforced read-only mode, which
  makes the read-only promise structural rather than editorial.

## The icons

<p align="center">
  <img src="docs/menubar-states.png" alt="The menu bar ring drawn at 0%, 2%, 12%, 24%, 75% and 100%, plus up, down and flat carets and the unset and error states" width="495">
</p>

Both icons are drawn in code rather than shipped as image files, so they stay crisp at any size and
are tuned in one place.

- **Menu bar.** A progress ring with your percentage inside it, filling as you approach your goal and
  becoming a checkmark when you get there. The caret beside it is emerald when the market is up, red
  when it is down, and absent when it has not moved. `make icons` renders every state, magnified.
- **App icon.** The same ring, glowing on a dark squircle. *Ziel* is German for target, so the mark is
  a target. `make icon` regenerates `Zielzeit.icns`.

## How the projection works

Your realized return uses the simple Dietz method, which approximates average invested capital by
assuming contributions arrive evenly through the year:

```
rate = gain₁ᵧ / (total − gain₁ᵧ − contributions/2)
```

Contributions are measured rather than guessed: Zielzeit walks the trailing year of
`sc broker transactions` and sums deposits less withdrawals. Securities movements are excluded,
because a custody migration would otherwise look like a year's worth of deposits. The rate is clamped
to ±30%, and suppressed entirely when the capital base works out to zero or less. That happens for a
portfolio younger than a year, where deposits rather than growth explain the balance.

Time to goal solves the monthly-compounding balance equation for `t`:

```
t = ln((G·r + P) / (V·r + P)) / ln(1 + r)
```

where `r` is the monthly rate (converted geometrically, `(1+annual)^(1/12) − 1`), `P` the monthly
contribution, `V` the current value and `G` the goal. If your savings plan has dynamization, the
annual step-up Scalable applies, the contribution becomes a step function that the closed form cannot
express. Zielzeit then walks forward one twelve-month block at a time and applies the same formula at
each year's contribution. That stays exact, and it is conservative about when the raise lands, since
the API does not say.

The chart plots the same recurrence forward, and a test asserts that each curve meets the goal line at
exactly the month the formula returns. That cross-check keeps the chart and the headline from
disagreeing.

**These are projections, not predictions.** They assume a constant return, smooth compounding and an
uninterrupted savings plan, none of which is how markets or life work. Before tax. Not financial
advice.

## Contributing

Contributions are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers the architecture, the make
targets, the UI harnesses, and how to exercise every state without touching a real account.

The short version:

```sh
make test     # run the complete ZielzeitCore test suite
make once     # print the report as text, the fastest check of the numbers
make ui       # rasterize the popover, light and dark
make help     # every target
```

One rule matters more than the rest: all arithmetic lives in `ZielzeitCore` and all UI in `Zielzeit`.
No `import SwiftUI` in the core, no math in the views. That split is what makes the projections
testable and the harnesses possible.

If Zielzeit is useful to you, a ⭐ on the repository is the cheapest way to say so, and it is what
helps other Scalable Capital investors find it.

## Disclaimer

Zielzeit is an independent, unofficial open-source project. It is not affiliated with, endorsed by, or
supported by Scalable Capital GmbH. "Scalable Capital" is their trademark, used here only to describe
what this app reads. Use at your own risk. The figures it shows are projections, and nothing in it is
financial advice.

## License

[MIT](LICENSE) © Istiaque Mannafee Shaikat

---

<sub>Keywords: Scalable Capital · scalable-cli · macOS menu bar app · portfolio tracker ·
investment goal calculator · FIRE calculator · compound interest projection · savings plan ·
Sparplan · Depot · ETF portfolio · Dietz return · Swift · SwiftUI · Swift Charts</sub>
