# Changelog

All notable changes to this project will be documented in this file.

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [3.0.0] - 2026-07-01

### Added

- Modern menu bar panel: clicking the status icon now opens a SwiftUI dropdown
  with the app header, a master gestures switch, a visual 2×2 gesture grid with
  instant toggles, and Settings / About / Quit rows — replacing the old
  AppKit `NSMenu` list.
- Status icon press bounce and panel content that always sizes to fit.
- Accessibility warning banner in the panel with a shortcut back to the
  guided onboarding window when permission is missing.
- Event tap resiliency for an always-on app: the tap re-enables itself after
  `tapDisabledByTimeout` / `tapDisabledByUserInput` and re-asserts after wake
  from sleep.
- Standard Swift project workflow tooling: shared formatting config, Makefile
  checks, optional Lefthook hooks, public agent guide, and contributor/security
  docs.
- Stable local development signing via `SigningDefaults.xcconfig` /
  `Signing.xcconfig.example` plus `make install-dev` for fast local reinstalls
  without resetting macOS permission grants.

### Changed

- Settings moved into a single consolidated window: gesture showcase carousel
  plus a General section (Launch at Login, Reset to Defaults). The menu bar
  panel stays lightweight.
- Permission onboarding window now hugs its content (no fixed height or dead
  space), enters with a fade-and-rise animation, and celebrates the grant with
  a green flash before closing.
- Brand accent unified to the cyan of the app icon across panel, About, and
  onboarding.
- Launch at Login is no longer force-registered on every launch; it is enabled
  once on first run and the toggle always reflects the real `SMAppService`
  state.
- Middle-button clicks pass through to native behavior when both middle-button
  gestures (Mission Control, Switch Spaces) are disabled.
- Moved local signing identity out of the tracked Xcode project and into the
  ignored `Signing.xcconfig` override used for developer installs.

### Fixed

- The settings window no longer flashes on launch or when reopening the app:
  the SwiftUI `WindowGroup` was removed and the app is now fully status-bar
  driven, so relaunching shows nothing.

### Removed

- Manual Appearance override (System / Light / Dark). The UI now always
  follows the system theme.
- Event "batching" machinery in the event monitor, and the `mouseMoved` event
  tap subscription — plain cursor movement no longer wakes the process, and
  gesture events are handled synchronously on the tap callback.

## [2.1.2] - 2026-05-29

### Changed

- Distribution-only patch: the macOS DMG is signed with Developer ID Application,
  notarized, stapled, and validated for Gatekeeper. No app behavior changed.

## [2.1.1] - 2026-05-15

### Added

- Drag-to-grant Accessibility onboarding: guided setup opens System Settings,
  floats a helper card anchored to the Accessibility pane, and auto-dismisses
  when permission is granted.
- Refreshed About panel with monospace version/build, feature chips, separator,
  auto-updating copyright year, and softer gradient background.

### Fixed

- Rebuilt the hosting view on every settings show so gesture carousel animations
  stay fluid after closing and reopening the window.

## [2.1.0] - 2026-05-14

### Changed

- Bumped version metadata and refreshed the About panel copy for the 2.1 line.

## [2.0.0] - 2025-11-21

### Added

- Compact settings layout with interactive gesture showcase carousel.
- Animated gesture previews for Mission Control, space navigation, scroll zoom,
  and invert-scroll demos.
- Separate About window and reordered onboarding slides.

### Changed

- Complete UI rewrite focused on the status-bar-first workflow and focused
  settings surface.

### Removed

- Side mouse button (buttons 3/4) handling so back/forward use native macOS
  behavior.

## [1.2.0] - 2025-11-21

### Changed

- Menu bar app behavior: status bar toggle, dropdown menu, and accessory-style
  presentation without duplicate windows.

## [1.1.2] - 2025-11-21

### Added

- Native side-button support before later removal in 2.0.0.

## [1.1.1] - 2025-10-02

### Fixed

- Critical stability fixes for gesture monitoring and window lifecycle edge cases.

## [1.1.0] - 2025-10-02

### Added

- Granular controls for drag threshold, invert direction, scroll zoom, and
  launch-at-login options.

## [1.0.1] - 2025-08-23

### Changed

- Performance and UI polish for the initial public release line.

## [1.0.0] - 2025-08-12

### Added

- First stable release: middle-click Mission Control, middle-click drag for
  space navigation, Ctrl+scroll zoom, and natural scroll inversion for macOS.
