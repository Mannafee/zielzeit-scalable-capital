# Contributing to Zielzeit

Thanks for taking a look. This is a small, opinionated codebase. This document covers what you need
to build it, how to see your change without a broker account, and the rules that keep the numbers
accurate.

## Getting set up

```sh
git clone https://github.com/Mannafee/zielzeit-scalable-capital.git
cd zielzeit-scalable-capital
make test     # 251 tests, about 5 seconds. Start here.
make once     # print the report as text (needs a connected CLI, or use the stub below)
```

You need macOS 15 or later and Xcode 16 or later (or an equivalent Swift 6 toolchain). You do not
need a Scalable Capital account to work on almost anything. See
[Working without a broker account](#working-without-a-broker-account).

## The one architectural rule

All arithmetic lives in `ZielzeitCore`. All UI lives in `Zielzeit`.

- No `import AppKit` or `import SwiftUI` in `ZielzeitCore`.
- No math in the view layer. If a view needs a number, add it to `Report` and read it.

That split is the whole reason the projections are unit-testable and the two UI harnesses work. A PR
that computes a figure inside a `View` will be asked to move it.

## Layout

```
Sources/ZielzeitCore/          pure logic, and where every test points
  Projection.swift               compounding math, balance curves, the inverse solve
  Report.swift                   view model: scenarios, chart curves, what-ifs, rows
  MarketMove.swift               return windows, direction, derived percentages
  Disclaimer.swift               the caveats, built from the report
  Formatting.swift               euro / percent / column formatting
  ScalableClient.swift           read-only `sc` invocation and decoding
  PortfolioSnapshot.swift        the data model and PortfolioProviding protocol
  GoalStore.swift                goal persistence and amount parsing
  Setup.swift                    onboarding state, access request, mailto builder
  RefreshPolicy.swift            backoff after a failed fetch
  Defaults.swift                 the shared preferences domain

Sources/Zielzeit/              the app: AppKit and SwiftUI, no arithmetic
  main.swift                     entry point and mode dispatch
  AppModel.swift                 @Observable state, fetching, goal actions
  StatusItemController.swift     menu bar item, popover, wake and theme observers
  PopoverView.swift              popover layout, facts, footer, empty states
  HeroView.swift                 headline year, sentence, progress bar
  ProjectionChartView.swift      the Swift Charts projection
  ScenarioListView.swift         the three scenario rows
  WhatIfSliderView.swift         "save more"
  TargetYearSliderView.swift     "reach by"
  MarketChipView.swift           the market movement chip
  DisclaimerView.swift           collapsible caveats
  GoalEditorView.swift           inline goal editing
  SetupView.swift                the onboarding checklist
  Theme.swift                    colour, type, metrics
  StatusItemIcon.swift           the drawn menu bar ring
  AppIconArtwork.swift           the drawn app icon
  ViewState.swift                setup / noGoal / loading / ready / failure
  LaunchAtLogin.swift            SMAppService wrapper
  TextMode.swift                 --once
  RenderMode.swift               --render, --icons, --appicon
  DevState.swift                 named states for both harnesses

Tests/ZielzeitCoreTests/       251 tests, including decoding against payloads
                               shaped from real CLI responses (never real data)
```

`CLAUDE.md` in the repo root is a long-form engineering log: why each decision was made and which
"obvious improvements" were tried and rejected. Worth skimming before you change behaviour, because
several things that look like bugs are load-bearing.

## Make targets

| Target | What it does |
|---|---|
| `make test` | Run the unit tests |
| `make audit` | Check the read-only and privacy claims against the source |
| `make check-docs` | Check every README image is published at a whole-number pixel ratio |
| `make once` | Print the whole report as text, the fastest check of the numbers |
| `make ui` | Rasterize the popover to `.build/ui-{light,dark}.png` |
| `make shots` | Regenerate the README screenshots in `docs/` from synthetic data |
| `make icons` | Draw the menu bar glyph at every progress value, with fit diagnostics |
| `make open` | Launch with the popover already open, for a real screenshot |
| `make icon` | Regenerate `Zielzeit.icns` from `AppIconArtwork` |
| `make app` | Package `Zielzeit.app` |
| `make run` | Package and launch |
| `make install` / `make uninstall` | Copy to `/Applications` / remove it and the saved goal |
| `make release` | Build the universal `.zip` and `.dmg` downloads into `dist/` |
| `make clean` | Delete build products |

## Seeing your change

There are four ways to look at the app, and each has a blind spot:

| | What it shows | Limitation |
|---|---|---|
| `make once` | The numbers, as text | No UI at all |
| `make ui` | The popover rasterized offscreen, both appearances, crisp at 2× | `ImageRenderer` cannot rasterize AppKit-backed controls, so the two sliders and the footer menu come out as coloured blocks. That is not a bug in your change. |
| `make shots` | The same thing with the real controls, at 4× | Prominent buttons draw grey rather than in the accent colour (see the note on `RenderMode.shot`). Dark appearance only. |
| `make open` | The real popover, real controls, real colours | You have to screenshot it yourself (`screencapture -R<x,y,w,h>`), and on a non-Retina display you only get 1× |

`make shots` regenerates the README images in `docs/`. It hosts the popover in an offscreen window and
captures it into a bitmap allocated at several times the pixel count, which is how a Retina asset
comes out of a non-Retina Mac. Prefer it to a screen capture when you need a crisp image. Check the
result against the `width=` the README displays it at: the source needs at least twice that.

Both `make ui` and `make open` take `STATE=`, so any state can be inspected on demand instead of
waiting for it to happen:

```sh
make ui STATE=editing
make open STATE=market-down
```

`STATE` is one of: `ready`, `slider`, `target-year`, `caveats`, `market-down`, `no-goal`, `loading`,
`failure`, `editing`, `setup-cli`, `setup-access`, `setup-requested`.

`market-down` exists because which windows are negative changes daily, and the losing colour is
otherwise unreviewable on demand.

**Judge the menu bar glyph with `make icons`, never by eye from a screenshot of the real bar.** At
20pt, magnification blur reads as digits colliding with the ring when they are not, which is why
`--icons` prints a fit ratio per value.

## Working without a broker account

Two environment variables are honoured by every mode:

- `ZIELZEIT_GOAL` sets a goal without touching the saved one
- `ZIELZEIT_SC_BIN` points at a stub in place of the real CLI

Failure paths need nothing more than:

```sh
ZIELZEIT_SC_BIN=/usr/bin/false swift run Zielzeit --once      # no output
ZIELZEIT_SC_BIN=/nonexistent/sc swift run Zielzeit --once     # CLI missing
```

For a full, realistic app with synthetic data, `Scripts/sc-demo` answers every read-only command
Zielzeit uses with invented but internally consistent figures: a €42 350 portfolio, a €500/mo plan
with a 5% step-up, and a 19.7% trailing pace. It is what the README screenshots are made from.

```sh
ZIELZEIT_SC_BIN=$PWD/Scripts/sc-demo ZIELZEIT_GOAL=250000 make once
ZIELZEIT_SC_BIN=$PWD/Scripts/sc-demo ZIELZEIT_GOAL=250000 make open STATE=ready
```

It also carries a `NON_TRADE_SECURITY_TRANSACTION` and an `INTEREST` entry in its transaction list, so
running against it exercises the filtering that keeps a custody migration from being counted as a
year's worth of deposits.

To walk the real onboarding while you still have a working session, point at a stub that fails
everything except `installation-code`, which needs no session and can be forwarded to the real CLI:

```sh
cat > .build/sc-no-session <<'EOF'
#!/bin/sh
case "$1" in
  installation-code) exec /opt/homebrew/bin/sc "$@" ;;
  *) echo "error: no saved session, please run sc login" >&2; exit 1 ;;
esac
EOF
chmod +x .build/sc-no-session
ZIELZEIT_SC_BIN=$PWD/.build/sc-no-session ./Zielzeit.app/Contents/MacOS/Zielzeit --open &
```

Afterwards, `make run` restores the real app, and clear the test residue with
`defaults delete com.zielzeit.Zielzeit hasRequestedAccess`.

## Hard constraints

These are not style preferences. A PR that breaks one will not be merged.

1. **Read-only, always.** Never invoke `sc broker trade` or any other write command.
   `ScalableClient.Command` enumerates the only five commands this project may run. Adding a sixth
   needs a very good reason and must still be read-only.
2. **Never run `sc login`,** and never touch the user's credentials.
3. **Never bundle the Scalable CLI** in the app bundle or the repo.
4. **Invoke `sc` by absolute path.** An app launched from Finder inherits a minimal `PATH` without
   `/opt/homebrew/bin`, so a bare `sc` works in your shell and fails only in the built app.
5. **Never commit real portfolio figures**, in screenshots, fixtures or test data. A fixture copied
   from the live CLI must have its amounts, installation codes and ISINs replaced first.

## Changing the math

If you touch `Projection` or `Report`:

- **Write the test first.** Everything in `ZielzeitCore` is testable with no UI and no account.
- The edge cases already covered must stay covered: `V ≥ G`, `r = 0` with and without savings,
  `r < 0` (where flat contributions cap the balance at `−P/r`, putting a goal above that out of
  reach), a portfolio younger than a year, and dynamization off-by-ones at months 11/12/13/24/25.
- The chart and the headline share one code path on purpose, and a test asserts each curve meets the
  goal line at exactly the month `monthsToGoal` returns. Don't break that cross-check. It is what
  keeps the picture and the number from drifting apart.
- `Disclaimer` builds its caveats *from the report*, so if you add an assumption, add its line and
  assert it in **both** directions. Only the absence assertions catch a caveat that has stopped
  matching the arithmetic.
- The projection must never flatter. A measured pace too poor to reach the goal shows no year, rather
  than quietly substituting the moderate scenario.

## What CI checks

`.github/workflows/ci.yml` runs on every push and pull request. Three jobs, each guarding something
you can plausibly break without noticing locally:

| Job | What it guards |
|---|---|
| **Tests** | `swift build --build-tests` and `swift test` on `macos-15` |
| **App bundle and harnesses** | `make app` (packaging: a missing `Info.plist` key, an icon that stops generating), a full `--once` run against `Scripts/sc-demo`, the documented `--once` exit codes, and both render harnesses |
| **No real account data** | Scans the tree for anything shaped like a real Scalable installation code or a real ISIN |

The end-to-end job is the one worth understanding: it runs the whole report against the synthetic CLI,
so a decoder change that compiles and passes the unit tests but falls over on a complete payload gets
caught. It needs no account and no network.

The hygiene job exists because the fixtures are shaped from real CLI responses, which makes pasting a
live one in easy to do by accident. If it fails on a legitimate placeholder, add the placeholder to
its allow-list rather than loosening the pattern.

Run all three locally before pushing:

```sh
make test && make app && make shots
```

## Cutting a release

One command:

```sh
Scripts/release              # infer the version from the commits since the last tag
Scripts/release 1.4          # use this version
Scripts/release minor        # force the bump kind (major|minor|patch)
Scripts/release --dry-run    # print the plan, change nothing
```

It bumps `CFBundleShortVersionString` and `CFBundleVersion`, runs the tests, opens the bump PR,
waits for CI, merges, tags, and waits for the release build. `.github/workflows/release.yml` picks
the tag up from there: tests, a universal binary (`arm64` and `x86_64`, so Intel Macs are covered),
a `.zip` and a drag-to-Applications `.dmg` (twice: once versioned, once as a plain `Zielzeit.dmg`
for the permanent download link), published with install instructions. `make release` builds the
same artifacts locally if you need to check one by hand.

The script does the steps in that order because doing them by hand is what went wrong. Three of its
checks are there for specific failures that have already happened:

- **The bump goes through a pull request.** `main` is protected, and a direct push is rejected by
  the branch hook.
- **The published release is verified to carry all three assets, and both download URLs are
  fetched.** The third asset is `Zielzeit.dmg`, an unversioned copy of the same disk image, and it
  is what makes `releases/latest/download/Zielzeit.dmg` a link that survives the next release. Every
  link already handed out points there, including ones in comments nobody can go back and edit, so
  a release that omits it does not leave the old link serving the previous version, it breaks it.
  v1.1
  went out with an empty asset list: the workflow's draft was left sitting and a second release was
  created on the same tag from the GitHub UI, which is a *new* release rather than an edit of the
  draft, so the artifacts stayed behind. The workflow publishes directly now, so there is no draft
  to strand — don't put `draft: true` back without also removing that verification.
- **The version can always be given explicitly.** It is otherwise inferred from the commit subjects
  since the last tag, and this history mixes conventional prefixes with plain prose, so an
  unprefixed subject is counted as a patch. Check what the script prints before trusting it.

Two more things to know:

- **`make app` builds for the host architecture only,** which keeps the development loop fast. Only
  `make release` goes universal, so never ship the output of `make app`.
- **The artifacts are ad-hoc signed, not notarized.** There is no paid Apple Developer ID behind this
  project, so a downloaded copy trips Gatekeeper and the user has to click *Open Anyway* once. The
  README and the release notes both explain that. Don't drop the ad-hoc signature to try to avoid it.
  It doesn't help, and macOS needs a signature before it will register the app as a login item. If a
  Developer ID ever gets added, sign and notarize in the workflow and delete those instructions.

## The update signing key

Releases are verified with EdDSA, not with an Apple Developer ID — there isn't one. The public half is
`SUPublicEDKey` in `Info.plist`; the private half is in the maintainer's **login Keychain** and is
never a GitHub secret, because a secret is readable by anything running in the release workflow, and
this repo is public and that workflow uses third-party actions. A leak means pushing arbitrary code to
every user of an app that reads their brokerage account.

The consequence is that **a release can only be cut from the machine holding that key.**
`Scripts/release` signs the appcast locally after the workflow publishes, then uploads it.

**Losing the key is not recoverable.** Every installed copy trusts only that key, so a new one means
no existing installation can ever be updated again — every user would have to find out by other means
and download by hand, which is the exact situation Sparkle is here to prevent. Confirm it is present
with `.build/sparkle-tools/<version>/bin/generate_keys -p`, and back it up outside the Keychain.

That path only exists after `Scripts/release` has fetched the Sparkle tools at least once — it is
not checked in, and on a machine you are restoring (the exact case where confirming the key matters
most) it will not be there yet. `Scripts/release --dry-run` stops well before that fetch, so it will
not create it either. Fetch the tarball the same way `sparkle_tools()` does — the URL, version and
`SPARKLE_SHA` below are copy-pasteable from `Scripts/release` — and extract it to that path yourself
before running `generate_keys -p`.

The signing tools are not in Sparkle's SPM package; `Scripts/release` fetches the official tarball
against a pinned SHA-256. Bumping `SPARKLE_VERSION` there means updating `SPARKLE_SHA` in the same
commit, and the `from:` version in `Package.swift` alongside it.

**"Pinned" here means `Package.resolved`, not the `from:` requirement.** `Package.swift` declares
`from: "2.9.4"`, which SwiftPM resolves as `>=2.9.4 <3.0.0` — a floor, not a pin. The version actually
built is whatever `Package.resolved` records, which is the committed pin. Running
`swift package update` moves that pin to the newest matching release without touching
`SPARKLE_VERSION`/`SPARKLE_SHA` in `Scripts/release`, so the framework and the signing tools can drift
out of step. Bump all three together.

## Submitting

1. Branch off `main`.
2. `make test` must pass, all 251 of them.
3. If you changed UI, attach a `make ui` or `make open` screenshot to the PR.
4. Keep commit messages descriptive of the *why*; the codebase's comments are written that way too.
5. Open a PR against `main` describing what changed and how you verified it.

Found a bug or have an idea? Open an issue at
<https://github.com/Mannafee/zielzeit-scalable-capital/issues>. Please don't include real account figures.
