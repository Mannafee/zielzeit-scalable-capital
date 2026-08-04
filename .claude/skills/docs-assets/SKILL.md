---
name: docs-assets
description: Use when a change affects what the README, the site or the film shows — the popover layout, the menu bar glyph, the app icon, the onboarding steps, or the site hero. Picks which of the four generation targets to run, and checks the result.
disable-model-invocation: true
---

# Regenerating the published assets

Four targets write committed binary assets. They cost wildly different amounts
of time, and three of them are deliberately **not** part of `make shots`, so
running the wrong one is either forty wasted seconds or a README whose
screenshots no longer match the app.

| Target | Cost | Regenerate when |
|---|---|---|
| `make shots` | seconds | the popover, the onboarding checklist or the menu bar glyph changed |
| `make demo` | ~40s | the popover's **layout** changed (it sweeps the save-more slider) |
| `make film` | ~80s capture + seconds composite | the popover layout changed *and* the site hero should follow |
| `make social` | seconds | the card artwork or the tagline changed |

Pick the narrowest one that covers the change. A copy tweak in a scenario label
needs `shots`, not `film`.

## Rules that outlive any one run

- **Every image's source width must be exactly twice its `width=` in the
  README** — `--scale 2` for popover and setup shots (688px → `width="344"`),
  `--scale 8` for the menu bar item (596px → `width="298"`), `width="495"` for
  the 1980px states sheet. Exactness is the whole point, not a minimum: a
  fractional ratio reads soft *however much resolution you throw at it*, and
  raising the scale factor does not fix it. Verify with
  `Scripts/check-doc-widths`, which is also wired to the post-edit hook.
- **Always against `Scripts/sc-demo`, never a real account.** No published image
  may carry a real balance, contribution, installation code or ISIN. CI's
  hygiene job fails the build on those shapes.
- `make film` is the one docs-build step that needs **ffmpeg** (ImageIO cannot
  write h264). It checks and says how to get it. `make demo` does not.
- If `FilmArtwork`'s captions change, update the transcript list in the site's
  film dialog too, or it stops being a transcript.

## After running

1. `Scripts/check-doc-widths` — the pixel arithmetic, all seven images.
2. `git status docs/` — confirm only the assets you intended moved. These are
   binaries; a stray regeneration is a large diff that reviews as noise.
3. Look at the output. `make demo` and `make film` can produce a frozen curve or
   a mistimed cut that no check catches and the eye catches immediately.
