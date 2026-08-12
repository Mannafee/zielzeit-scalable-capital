# Zielzeit cleanup brief

Clean up this codebase to a high standard **without changing what the app does**.
Work on the current branch (`feature/fix`), committing after each verified unit of work.

## The gate — non-negotiable

After every change, run:

    Scripts/cleanup-gate

It must print `GATE PASS`: clean build with **zero** compiler warnings, 297 tests
passing, audit 7 of 7, and the report byte-identical in 5 languages.

- If it fails, revert with `git checkout -- <file>` and try a different approach.
- **Never** commit with a failing gate.
- **Never** edit `Scripts/cleanup-gate`, the tests, or the recorded golden to make
  the gate pass. That defeats its entire purpose. If you believe the golden is
  genuinely wrong, stop and say so instead of changing it.

## In scope, highest value first

1. Dead code, unused imports, unused properties and helpers, duplicated logic
   across `Sources/`.
2. Split the oversized files into focused files or extensions — **pure code
   movement**, no logic edits in the same commit:
   - `Sources/ZielzeitCore/Localization.swift` (815 lines)
   - `Sources/Zielzeit/HoldingsView.swift` (812)
   - `Sources/Zielzeit/RenderMode.swift` (750)
   - `Sources/ZielzeitCore/Report.swift` (626)
   - `Sources/ZielzeitCore/ScalableClient.swift` (617)
   - `Sources/Zielzeit/PopoverView.swift` (612)
3. Naming and consistency; tighten access control, `internal` to `private` where
   nothing outside needs it.
4. Internal refactors: extract types, simplify the state flow in `AppModel.swift`,
   tighten APIs.
5. `site/index.html`, `site/style.css` (42 KB, likely carries dead rules),
   `site/main.js`. Check a rule is truly unused across the HTML before removing it.

## The one constraint that matters most

This codebase's dominant failure mode is **changes that undo a deliberate decision
rather than fix a bug**. Much of what looks like redundancy here is load-bearing,
and the comments usually say so.

Before deleting or "simplifying" anything:

- Read the surrounding comments.
- Run `git log -S'<the code>'` to find out why it was introduced.
- If a comment or commit explains the reason, **the code stays**.
- If you cannot establish why something exists, **leave it alone** and move on to
  something you do understand.

A smaller, certain cleanup beats a large, risky one. When torn, keep the code.

## Do not

- Change user-visible strings or translations.
- Change the public API of `ZielzeitCore` without a clear need.
- Touch the Makefile release, signing, or notarisation targets.
- Reformat whole files for style alone — it buries real changes in noise.
- Add dependencies.
- Regenerate screenshots, GIFs, or video assets.

## Commits

Small and single-purpose. The message explains **why**, not just what.

## Finishing

Stop when what remains is judgement calls a human should make. Then output a
summary of what you changed and — just as important — what you deliberately left
alone and why, followed by the completion promise.
