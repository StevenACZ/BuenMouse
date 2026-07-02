# BuenMouse Agent Guide

Public-safe operating notes for coding agents. Keep private machine-specific
workflows, signing material, logs, crash reports, release artifacts, and local
planning in ignored local files. Speak Spanish with Steven; write code,
commits, changelogs, and durable technical docs in English.

## Product

- macOS menu bar app for advanced mouse gestures.
- Minimum macOS: 15.0.
- UI stack: SwiftUI + AppKit.
- Main target: `BuenMouse` in `BuenMouse.xcodeproj`.
- Status-bar-first app; no Dock icon.
- Accessibility permission is required for the event tap; Apple Events is
  used for Mission Control / Spaces actions.

## Architecture

Status-bar-first: the SwiftUI `App` body is an empty `Settings` scene; every
real window is created and owned by AppKit controllers. Never reintroduce a
`WindowGroup` — it opens (and flashes) a window on every launch.

- `BuenMouseApp.swift`: hollow entry point (`Settings { EmptyView() }`).
- `AppDelegate.swift`: app lifecycle, event stack wiring, permission
  onboarding, wake-from-sleep tap re-assert. Reopen is a no-op by design.
- `ServiceManager.swift`: thin `SMAppService` wrapper for launch-at-login.
- `Core/MenuBar`: `MenuBarStatusController` — status item, transient
  `NSPopover` panel (SwiftUI content, self-sizing), Settings/About windows.
- `Core/EventHandling`: event tap setup, gesture state, scroll inversion, and
  Ctrl-scroll zoom. The tap mask excludes `mouseMoved` and the callback
  re-enables the tap on `tapDisabledByTimeout` — keep both properties; the
  app runs 24/7.
- `Core/Permissions`: Accessibility onboarding window (content-hugging) and
  the drag-to-grant System Settings overlay.
- `Core/Settings`: persisted settings and protocol surface for views.
- `Core/SystemActions`: local macOS actions such as Mission Control / Spaces.
- `Core/Helpers`: `LocalizationManager` (en/es app language, persisted to
  `appLanguage`, follows the macOS UI language on first launch) and the
  `String.localized` lookup extension. All user-facing copy lives in
  `Resources/{en,es}.lproj/Localizable.strings` — never hardcode UI strings.
- `Core/UI/Theme.swift`: brand accent (cyan) and shared animation constants.
- `Views/MenuBar`: dropdown panel (header + gesture grid + action rows).
- `Views/Settings`: consolidated settings window (showcase + general options).
- `Views/About`, `Views/Permissions`, `Views/Components`: About panel,
  onboarding content, shared gesture metadata.

UI conventions: SwiftUI content hosted in AppKit windows via
`NSHostingController`; window content is rebuilt on each show and dropped on
close so timers never run hidden; appearance always follows the system.

## Guardrails

- Keep gesture behavior local to macOS. Do not add cloud relay, telemetry, or
  credential storage without explicit design approval.
- Do not commit certificates, provisioning profiles, Team IDs, local Xcode user
  data, logs, crash reports, DMGs, archives, or environment files.
- Do not add an in-app changelog or "What's New" surface; release notes belong
  in `CHANGELOG.md` and GitHub Releases.
- Preserve the status-bar-first workflow and focused settings surface.
- Side mouse buttons 3/4 are intentionally left to native macOS back/forward
  behavior.
- Ask before installing, relaunching, committing, pushing, merging, tagging, or
  publishing a release.

## Build And Verification

Use the Makefile for the standard local gate:

```bash
make ci-check
```

- `make ci-check` runs Swift formatting lint plus a Release build.
- The project does not have a unit test target yet; there is no `make test`
  gate.
- Use `make format` / `make lint` before commits; optional Lefthook via
  `make hooks-install`.
- Run `git diff --check` before staging or reporting a patch done.

Direct build command:

```bash
xcodebuild -project BuenMouse.xcodeproj -scheme BuenMouse \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath ./build_check build
```

## Local Testing

Use `make install-dev` for routine local app testing on Steven's Mac after he
has approved installation/relaunch for the task. It builds a signed Release app,
reinstalls to `/Applications/BuenMouse.app`, and relaunches it. Keeping the same
app name, bundle id, and Apple Development signing identity preserves the
Accessibility grant across rebuilds.

Useful runtime log stream:

```bash
/usr/bin/log stream --style compact --predicate 'process == "BuenMouse"'
```

Crash reports land under `~/Library/Logs/DiagnosticReports/BuenMouse-*.ips`.

## Documentation

- Keep `CHANGELOG.md` in Keep a Changelog style with `[Unreleased]` at the top.
- Record meaningful user-facing, maintainer, permission, or release workflow
  changes.
- Keep README, contributor docs, security notes, and release notes aligned with
  actual behavior.
- Keep this guide compact and public-safe; move long runbooks or private
  workflows into ignored local docs.

## Release

- Build and validate the Release app before packaging.
- DMGs are release-only; do not create one for routine local verification.
- Use `make notarized-dmg` only when Steven approves release packaging.
- Do not create GitHub releases, tags, or release notes without explicit
  approval.

## Git

- Do not run `git add`, commit, push, PR creation, merge, rebase, reset, branch
  deletion, tag, or release publication without explicit approval.
- Do not revert unrelated user changes.
- Use Conventional Commits if asked to commit.
