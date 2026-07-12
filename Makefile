.PHONY: help tools format format-all lint lint-all build release install-dev size-check ci-check release-check notarized-dmg appcast hooks-install

.DEFAULT_GOAL := help

PROJECT := BuenMouse.xcodeproj
SCHEME := BuenMouse
SWIFT_FORMAT := xcrun swift-format
SWIFT_FORMAT_CONFIG := .swift-format
RELEASE_DERIVED_DATA := ./build_check
RELEASE_APP := $(RELEASE_DERIVED_DATA)/Build/Products/Release/BuenMouse.app

help:
	@printf "BuenMouse developer commands\n\n"
	@printf "  make tools         Check required local tools\n"
	@printf "  make format        Format changed Swift files with Xcode swift-format\n"
	@printf "  make format-all    Format all Swift sources explicitly\n"
	@printf "  make lint          Check changed Swift files without editing files\n"
	@printf "  make lint-all      Check all Swift sources explicitly\n"
	@printf "  make build         Build Release for Apple Silicon\n"
	@printf "  make release       Build Release for Apple Silicon\n"
	@printf "  make install-dev   Reinstall signed Release build to /Applications\n"
	@printf "  make size-check    Measure the Release app bundle\n"
	@printf "  make ci-check      Local gate: lint + Release build\n"
	@printf "  make release-check Release gate: lint + Release build + size check\n"
	@printf "  make notarized-dmg Build, sign, notarize, staple, and validate the release DMG\n"
	@printf "  make appcast       Zip the notarized app, EdDSA-sign it, and write appcast.xml\n"
	@printf "  make hooks-install Install optional Lefthook git hooks\n"

tools:
	@xcrun --find swift-format >/dev/null
	@xcodebuild -version >/dev/null
	@printf "tools: xcodebuild and swift-format are available\n"

format: tools
	@scripts/swift_format_changed.sh format

format-all: tools
	$(SWIFT_FORMAT) format --in-place --recursive --parallel \
		--configuration $(SWIFT_FORMAT_CONFIG) \
		.

lint: tools
	@scripts/swift_format_changed.sh lint

lint-all: tools
	$(SWIFT_FORMAT) lint --strict --recursive --parallel \
		--configuration $(SWIFT_FORMAT_CONFIG) \
		.

build release:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Release -destination 'generic/platform=macOS' \
		-derivedDataPath $(RELEASE_DERIVED_DATA) build

install-dev:
	@chmod +x scripts/install_dev.sh
	@scripts/install_dev.sh

size-check:
	@test -d "$(RELEASE_APP)" || { echo "Release app not found. Run: make release"; exit 66; }
	@du -sh "$(RELEASE_APP)" "$(RELEASE_APP)/Contents/MacOS/BuenMouse" "$(RELEASE_APP)/Contents/Resources"
	@printf "archs: "
	@lipo -archs "$(RELEASE_APP)/Contents/MacOS/BuenMouse"
	@find "$(RELEASE_APP)" -maxdepth 4 -type f | sort

ci-check: lint build
	@printf "ci-check: passed\n"

release-check: lint release size-check
	@printf "release-check: passed\n"

notarized-dmg:
	@scripts/package_notarized_dmg.sh

appcast:
	@chmod +x scripts/generate_appcast.sh
	@scripts/generate_appcast.sh

hooks-install:
	@command -v lefthook >/dev/null || { echo "lefthook is not installed. Install it with: brew install lefthook"; exit 69; }
	lefthook install
