# Security

## Secret Handling

Do not commit:

- API keys, tokens, or `.env*` files
- Signing certificates, provisioning profiles, notarization files, or private
  Xcode configuration
- Personal Apple Developer Team IDs, local Xcode user data, or machine-specific
  paths
- Private agent notes, local crash reports, DMGs, or archives

BuenMouse uses Accessibility (and Apple Events for system actions) for
gesture handling. Do not
add cloud relay, telemetry endpoints, or credential storage without an explicit
design and security review.

## Update Channel

In-app updates are served from GitHub Releases through a Sparkle appcast
(`appcast.xml` uploaded with each release). Updates install only if their
EdDSA signature matches the public key embedded in the app's Info.plist, so
only the maintainer holding the private key (stored in the maintainer's
Keychain, never in the repo) can publish an installable update.

## Reporting

For security-sensitive issues, do not include private logs or local identifiers
in public issues. Open a minimal report describing the affected area and share
sensitive details only through a private maintainer-approved channel.

## Public Repo Boundary

The public repo should contain source code, app assets, shared Xcode metadata,
build scripts, formatting config, README, changelog, contributing notes,
security notes, and license. Local maintainer notes and release artifacts stay
ignored unless they are scrubbed and intentionally published.
