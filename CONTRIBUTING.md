# Contributing

Thanks for helping improve BuenMouse.

## Setup

```bash
make tools
make ci-check
```

Open `BuenMouse.xcodeproj` in Xcode and run the `BuenMouse` scheme.

## Workflow

```bash
make format
make lint
make build
```

- Keep changes focused and small.
- Do not commit credentials, logs, crash reports, DMGs, archives, local docs,
  or signing files.
- The project does not have a unit test target yet; `make ci-check` is the
  current local gate (lint + Release build).
- Follow the branch-and-review workflow in `AGENTS.md` before committing.

## Pull Requests

Before opening a PR:

```bash
make ci-check
git diff --check
```

Include:

- What changed.
- How it was verified.
- Any permission, signing, or accessibility impact.

## Signing

Contributor builds use the tracked project signing defaults. Maintainers
configure Developer ID, notarization, and release DMG packaging outside routine
development commits.
