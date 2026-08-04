# Zielzeit: build, test, and package the menu bar app.

APP      := Zielzeit.app
BINARY   := .build/release/Zielzeit
CONTENTS := $(APP)/Contents

# Distribution artifacts. VERSION must match CFBundleShortVersionString in
# Info.plist, since the release workflow tags against it.
VERSION  := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
DIST     := dist
# A universal binary, so the download runs on Intel Macs too. `make app` builds
# for the host arch only, which is what you want while developing.
UNIVERSAL := .build/apple/Products/Release/Zielzeit

# Which state the UI harness targets: ready | slider | target-year | caveats |
# market-down | no-goal | loading | failure | editing | setup-cli |
# setup-access | setup-requested
STATE ?= ready

.DEFAULT_GOAL := help
.PHONY: help build test audit once ui shots demo film social icon icons open app run install uninstall clean \
        release release-app dmg zip site

help: ## Show available targets
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/' | expand -t 12

build: ## Compile in release mode
	swift build -c release

test: ## Run the unit tests
	swift test

audit: ## Check the read-only and privacy claims against the source (AUDIT_ARGS=-v)
	@# Needs no toolchain and no account: it reads Sources/ and Package.swift, so
	@# anyone deciding whether to trust the download can run it straight from a
	@# clone before building anything.
	@Scripts/audit $(AUDIT_ARGS)

check-docs: ## Check every README image is published at a whole-number pixel ratio
	@# Deliberately not folded into `audit`: that target backs one badge making one
	@# claim about the source, and image arithmetic is not that claim.
	@Scripts/check-doc-widths

once: ## Print the report as text (fast way to check the numbers)
	swift run Zielzeit --once

ui: ## Render the popover to PNGs, light and dark (STATE=ready|slider|editing|…)
	@swift build
	@.build/debug/Zielzeit --render .build/ui-light.png $(STATE)
	@.build/debug/Zielzeit --render .build/ui-dark.png $(STATE) --dark
	@echo "Open them with: open .build/ui-light.png .build/ui-dark.png"
	@echo "Note: AppKit-backed controls (slider, menus) do not rasterize. Use 'make open' for those."

site: ## Serve the GitHub Pages site locally at http://localhost:8000
	@# The screenshots live in docs/ and are copied in, exactly as the Pages
	@# workflow does it, so a local preview cannot differ from the published site.
	@mkdir -p site/img
	@# menubar-states.png is deliberately not copied: the site dropped the states
	@# strip, and docs/ still carries it for the README.
	@# social-preview.png is copied because the page's og:image points at it: the
	@# card has to be served from this origin, not linked out of docs/ on GitHub.
	@cp docs/icon.png docs/menubar.png \
	    docs/popover.png docs/popover-de.png \
	    docs/setup.png docs/setup-de.png \
	    docs/demo.gif docs/social-preview.png \
	    docs/promo.mp4 docs/promo-poster.jpg site/img/
	@echo "Serving site/ at http://localhost:8000  (ctrl-C to stop)"
	@python3 -m http.server 8000 --directory site

shots: ## Regenerate the README screenshots in docs/ from synthetic data
	@swift build
	@mkdir -p docs
	@# Always against the demo stub, never a real account, since these get published.
	@# 3×, not 2×: the README shows the popover at 380px wide, so a 2× shot lands at
	@# 1.8 device pixels per CSS pixel on a Retina screen and reads soft. 3× clears
	@# Retina with room to spare; 4× only costs file size.
	@# ZIELZEIT_LANG is set on every shot, English ones included: it outranks the
	@# stored preference, so without it a developer who has switched the app to
	@# German would quietly regenerate the English screenshots in German.
	@ZIELZEIT_SC_BIN=$(PWD)/Scripts/sc-demo ZIELZEIT_GOAL=250000 ZIELZEIT_LANG=en \
		.build/debug/Zielzeit --shot docs/popover.png ready --dark --scale 2
	@ZIELZEIT_SC_BIN=$(PWD)/Scripts/sc-demo ZIELZEIT_GOAL=250000 ZIELZEIT_LANG=en \
		.build/debug/Zielzeit --shot docs/setup.png setup-access --dark --scale 2
	@# The same two states in German. Same stub, same goal, same scale, so the
	@# pair differs only in language.
	@ZIELZEIT_SC_BIN=$(PWD)/Scripts/sc-demo ZIELZEIT_GOAL=250000 ZIELZEIT_LANG=de \
		.build/debug/Zielzeit --shot docs/popover-de.png ready --dark --scale 2
	@ZIELZEIT_SC_BIN=$(PWD)/Scripts/sc-demo ZIELZEIT_GOAL=250000 ZIELZEIT_LANG=de \
		.build/debug/Zielzeit --shot docs/setup-de.png setup-access --dark --scale 2
	@.build/debug/Zielzeit --menubar docs/menubar.png --dark --scale 8
	@.build/debug/Zielzeit --icons docs/menubar-states.png --dark >/dev/null
	@rm -rf .build/readme-iconset
	@.build/debug/Zielzeit --appicon .build/readme-iconset >/dev/null
	@cp .build/readme-iconset/icon_256x256@2x.png docs/icon.png
	@echo "Wrote docs/{popover,popover-de,setup,setup-de,menubar,menubar-states,icon}.png"

demo: ## Regenerate docs/demo.gif (the slider sweeping, for the top of the README)
	@# Deliberately not part of `shots`: it rebuilds the popover once per frame and
	@# takes about 40 seconds, and it only changes when the popover's layout does.
	@swift build
	@mkdir -p docs
	@ZIELZEIT_SC_BIN=$(PWD)/Scripts/sc-demo ZIELZEIT_GOAL=250000 ZIELZEIT_LANG=en \
		.build/debug/Zielzeit --demo docs/demo.gif --dark --scale 2

film: ## Regenerate docs/promo.mp4 + poster (the 25s tour on the site hero)
	@# Two stages, and the split is the point. Stage 1 captures 50 real plates
	@# through the same offscreen-window path `--shot` uses, paying its 1.5s
	@# layout settle once each (~80s). Stage 2 composites 750 frames from those
	@# plates with no AppKit layout at all, in seconds. Captured frame-by-frame
	@# the film would take about nineteen minutes.
	@#
	@# Deliberately not part of `shots`, for the same reason `demo` is not: slow,
	@# and only needed when the popover's layout changes.
	@#
	@# ffmpeg is the one docs-build tool this repo does not otherwise need, and
	@# that is a considered cost: ImageIO cannot write h264, and a 25-second GIF
	@# of this material is larger than the mp4 and worse.
	@#
	@# h264 only, no VP9 companion. Every current browser plays h264, VP9 would
	@# save perhaps a quarter of an already-small file, and a second codec means
	@# a second library for the docs build to depend on — which is what this
	@# repo spends its restraint avoiding.
	@command -v ffmpeg >/dev/null || { echo "film needs ffmpeg: brew install ffmpeg"; exit 1; }
	@swift build
	@mkdir -p docs
	@rm -rf .build/film-plates .build/film
	@ZIELZEIT_SC_BIN=$(PWD)/Scripts/sc-demo ZIELZEIT_GOAL=250000 ZIELZEIT_LANG=en \
		.build/debug/Zielzeit --film-plates .build/film-plates --scale 2
	@.build/debug/Zielzeit --film .build/film --plates .build/film-plates
	@ffmpeg -y -loglevel error -framerate 30 -i .build/film/frame-%04d.png \
		-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart \
		docs/promo.mp4
	@# t = 13.0s: popover open, chart and all three scenario rows visible. The
	@# poster is what everyone who never presses play actually sees.
	@#
	@# JPEG, not PNG, and it is the one asset here that should be lossy: this
	@# frame as a PNG is 1.7MB against 129KB at q3, and it introduces an h264
	@# video, so it cannot look worse than the thing it is a still of. Every
	@# other image this repo publishes stays PNG for the opposite reason — they
	@# are the product, not a placeholder for it.
	@ffmpeg -y -loglevel error -i .build/film/frame-0390.png -q:v 3 docs/promo-poster.jpg
	@# Stated rather than assumed, as `--social` states its budget: a film that
	@# quietly doubled in size is a slow hero nobody notices in review.
	@echo
	@# `stat -f%z`, not `du -k`: du reports allocated blocks, which on APFS came
	@# out 550KB above the real file size and made the budget this line exists to
	@# state a fiction.
	@for f in docs/promo.mp4 docs/promo-poster.jpg; do \
		printf "  %-28s %6d KB\n" "$$f" $$(( $$(stat -f%z "$$f") / 1024 )); \
	done

social: ## Regenerate docs/social-preview.png (the GitHub link-unfurl card)
	@swift build
	@mkdir -p docs
	@.build/debug/Zielzeit --social docs/social-preview.png
	@# There is no API for the social preview, so this is the manual half:
	@echo
	@echo "Upload it at Settings → General → Social preview:"
	@echo "  https://github.com/Mannafee/zielzeit-scalable-capital/settings"

icon: ## Generate Zielzeit.icns (the app icon) from the drawn artwork
	@swift build
	@rm -rf .build/Zielzeit.iconset
	@.build/debug/Zielzeit --appicon .build/Zielzeit.iconset
	@rm -f .build/Zielzeit.iconset/preview.png
	@iconutil --convert icns .build/Zielzeit.iconset --output Zielzeit.icns
	@echo "Wrote Zielzeit.icns"

icons: ## Render the menu bar icon at every progress value, magnified
	@swift build
	@.build/debug/Zielzeit --icons .build/icons-light.png
	@.build/debug/Zielzeit --icons .build/icons-dark.png --dark
	@echo "Open them with: open .build/icons-light.png .build/icons-dark.png"

open: app ## Launch with the popover already open, for screenshots (STATE=…)
	@pkill -x Zielzeit 2>/dev/null || true
	@./Zielzeit.app/Contents/MacOS/Zielzeit --open $(STATE) >/dev/null 2>&1 &
	@echo "Opened in state '$(STATE)'."

app: build Zielzeit.icns ## Package Zielzeit.app
	@rm -rf $(APP)
	@mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	@cp $(BINARY) $(CONTENTS)/MacOS/Zielzeit
	@cp Info.plist $(CONTENTS)/Info.plist
	@cp Zielzeit.icns $(CONTENTS)/Resources/Zielzeit.icns
	@# Sparkle goes in before the app is signed: signing the container first and
	@# then adding a nested bundle invalidates the container's signature.
	@Scripts/embed-sparkle $(APP)
	@# Ad-hoc signature: enough to launch, and required before macOS will
	@# consider the bundle for login-item registration. The app signs last.
	@codesign --force --sign - --identifier com.zielzeit.Zielzeit $(APP)
	@echo "Built $(APP)"

run: app ## Package and launch the app
	@pkill -x Zielzeit 2>/dev/null || true
	@open $(APP)
	@echo "Zielzeit is running. Look for the progress ring in the menu bar."

install: app ## Copy the app to /Applications
	@rm -rf /Applications/$(APP)
	@cp -R $(APP) /Applications/
	@echo "Installed to /Applications/$(APP)"

release: zip dmg ## Build the universal downloads (zip + dmg) into dist/
	@echo
	@echo "Ready in $(DIST)/. Attach all three to the GitHub release for v$(VERSION)."
	@echo "Zielzeit.dmg is the unversioned copy that keeps the permanent"
	@echo "/releases/latest/download/Zielzeit.dmg link working. Don't skip it."

# Same bundle as `app`, but built for both architectures so the download runs on
# Intel Macs as well as Apple silicon.
release-app: Zielzeit.icns
	@swift build -c release --arch arm64 --arch x86_64
	@rm -rf $(DIST)/$(APP)
	@mkdir -p $(DIST)/$(APP)/Contents/MacOS $(DIST)/$(APP)/Contents/Resources
	@cp $(UNIVERSAL) $(DIST)/$(APP)/Contents/MacOS/Zielzeit
	@cp Info.plist $(DIST)/$(APP)/Contents/Info.plist
	@cp Zielzeit.icns $(DIST)/$(APP)/Contents/Resources/Zielzeit.icns
	@# Same as `app`: the framework goes in before the container is signed.
	@Scripts/embed-sparkle $(DIST)/$(APP)
	@# Ad-hoc, as everywhere else here: there is no Developer ID to sign with,
	@# so the download is not notarized and macOS will ask the user to confirm
	@# it once. The README explains that step; don't quietly drop the signature,
	@# since login-item registration needs one.
	@codesign --force --sign - --identifier com.zielzeit.Zielzeit $(DIST)/$(APP)
	@lipo -archs $(DIST)/$(APP)/Contents/MacOS/Zielzeit

zip: release-app ## Zip the universal app for download
	@rm -f $(DIST)/Zielzeit-$(VERSION).zip
	@# ditto, not zip: it preserves the code signature and resource forks.
	@ditto -c -k --keepParent $(DIST)/$(APP) $(DIST)/Zielzeit-$(VERSION).zip
	@echo "Wrote $(DIST)/Zielzeit-$(VERSION).zip"

dmg: release-app ## Build a drag-to-Applications disk image
	@rm -rf $(DIST)/stage $(DIST)/Zielzeit-$(VERSION).dmg $(DIST)/Zielzeit.dmg
	@mkdir -p $(DIST)/stage
	@cp -R $(DIST)/$(APP) $(DIST)/stage/
	@ln -s /Applications $(DIST)/stage/Applications
	@hdiutil create -quiet -volname "Zielzeit $(VERSION)" -srcfolder $(DIST)/stage \
		-ov -format UDZO $(DIST)/Zielzeit-$(VERSION).dmg
	@rm -rf $(DIST)/stage
	@# An unversioned copy as well, and the name is the whole point: GitHub serves
	@# /releases/latest/download/<name>, so only a filename that never changes gives
	@# out a download link that survives the next release. Attach both.
	@cp $(DIST)/Zielzeit-$(VERSION).dmg $(DIST)/Zielzeit.dmg
	@echo "Wrote $(DIST)/Zielzeit-$(VERSION).dmg and $(DIST)/Zielzeit.dmg"

uninstall: ## Remove the installed app and its saved goal
	@pkill -x Zielzeit 2>/dev/null || true
	@rm -rf /Applications/$(APP)
	@defaults delete com.zielzeit.Zielzeit 2>/dev/null || true
	@echo "Removed."

# Regenerated on demand; `app` depends on it so a fresh clone builds with an icon.
Zielzeit.icns:
	@$(MAKE) --no-print-directory icon

clean: ## Delete build products
	swift package clean
	@rm -rf .build $(APP) $(DIST)
