.PHONY: help tools format format-all lint lint-all build ci-check hooks-install

.DEFAULT_GOAL := help

PROJECT := BuenMouse.xcodeproj
SCHEME := BuenMouse
SWIFT_FORMAT := xcrun swift-format
SWIFT_FORMAT_CONFIG := .swift-format
RELEASE_DERIVED_DATA := ./build_check

help:
	@printf "BuenMouse developer commands\n\n"
	@printf "  make tools         Check required local tools\n"
	@printf "  make format        Format changed Swift files with Xcode swift-format\n"
	@printf "  make format-all    Format all Swift sources explicitly\n"
	@printf "  make lint          Check changed Swift files without editing files\n"
	@printf "  make lint-all      Check all Swift sources explicitly\n"
	@printf "  make build         Build Release for Apple Silicon\n"
	@printf "  make ci-check      Local gate: lint + Release build\n"
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

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Release -destination 'generic/platform=macOS' \
		-derivedDataPath $(RELEASE_DERIVED_DATA) build

ci-check: lint build
	@printf "ci-check: passed\n"

hooks-install:
	@command -v lefthook >/dev/null || { echo "lefthook is not installed. Install it with: brew install lefthook"; exit 69; }
	lefthook install
