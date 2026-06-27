# BuenMouse Agent Guide

Public-safe operating notes for coding agents. Keep private machine-specific
workflows, signing material, logs, crash reports, release artifacts, and local
planning in ignored local files. Speak Spanish with Steven; write code,
commits, changelogs, and durable technical docs in English.

## Product

- macOS menu bar app for advanced mouse gestures.
- Minimum macOS: 13.0.
- UI stack: SwiftUI + AppKit.
- Main target: `BuenMouse` in `BuenMouse.xcodeproj`.
- Status-bar-first app; no Dock icon.
- Accessibility and Input Monitoring permissions are required for gesture
  handling.

## Architecture

- `BuenMouseApp.swift`: app entry point.
- `AppDelegate.swift`: window lifecycle and menu bar dropdown.
- `ServiceManager.swift`: launch-at-login integration.
- `Core/EventHandling`: event tap setup, gesture state, scroll inversion, and
  Ctrl-scroll zoom.
- `Core/Permissions`: Accessibility onboarding and System Settings helper UI.
- `Core/Settings`: persisted settings and protocol surface for views.
- `Core/SystemActions`: local macOS actions such as Mission Control / Spaces.
- `Views`: settings surface, gesture previews, and permission requirements UI.

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
app name, bundle id, and Apple Development signing identity preserves
Accessibility and Input Monitoring grants across rebuilds.

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
