import SwiftUI

/// Navigation / destructive row for the dropdown panel: icon, title,
/// optional subtitle, hover fill, and a trailing chevron.
struct ActionRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isDestructive ? Color.red : Color.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(isDestructive ? Color.red : Color.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isHovering ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// Accent update card: a pending update downloads on one click, then waits for
/// Install now / Later; a failed install offers a retry.
struct UpdateCard: View {
    @ObservedObject var manager: UpdateManager
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            controls
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                .fill(Theme.accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous))
        .animation(Theme.Anim.easeOut, value: manager.phase)
    }

    private var version: String {
        switch manager.phase {
        case .available(let version), .readyToInstall(let version), .failed(let version):
            return version
        case .idle, .downloading, .installing:
            return manager.pendingVersion ?? ""
        }
    }

    private var symbol: String {
        switch manager.phase {
        case .idle, .available: return "arrow.down.circle.fill"
        case .downloading: return "arrow.down.circle"
        case .readyToInstall: return "checkmark.circle.fill"
        case .installing: return "arrow.triangle.2.circlepath"
        case .failed: return "exclamationmark.arrow.circlepath"
        }
    }

    private var title: String {
        switch manager.phase {
        case .idle, .available:
            return version.isEmpty
                ? "update.card.available.title_generic".localized
                : "update.card.available.title".localized(version)
        case .downloading:
            return version.isEmpty
                ? "update.card.downloading.title_generic".localized
                : "update.card.downloading.title".localized(version)
        case .readyToInstall:
            return version.isEmpty
                ? "update.card.ready.title_generic".localized
                : "update.card.ready.title".localized(version)
        case .installing:
            return version.isEmpty
                ? "update.card.installing.title_generic".localized
                : "update.card.installing.title".localized(version)
        case .failed:
            return "update.card.failed.title".localized
        }
    }

    private var subtitle: String? {
        switch manager.phase {
        case .idle, .available: return "update.card.available.subtitle".localized
        case .downloading: return nil
        case .readyToInstall: return "update.card.ready.subtitle".localized
        case .installing: return "update.card.installing.subtitle".localized
        case .failed: return "update.card.failed.subtitle".localized
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch manager.phase {
        case .idle:
            EmptyView()

        case .available:
            prominentButton("update.card.button.update".localized) {
                manager.installPendingUpdate()
            }

        case .downloading(let fraction):
            HStack(spacing: 8) {
                if let fraction {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .tint(Theme.accent)
                    Text("update.card.percent".localized(Int((fraction * 100).rounded())))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(Theme.accent)
                }
            }

        case .readyToInstall:
            HStack(spacing: 8) {
                prominentButton("update.card.button.install_now".localized) {
                    manager.installNow()
                }
                if manager.canPostpone {
                    Button {
                        manager.installLater()
                    } label: {
                        Text("update.card.button.later".localized)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

        case .installing:
            ProgressView()
                .progressViewStyle(.linear)
                .tint(Theme.accent)

        case .failed:
            prominentButton("update.card.button.retry".localized) {
                manager.installNow()
            }
        }
    }

    private func prominentButton(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
    }
}

/// Warning banner shown while Accessibility access is missing.
struct PermissionBanner: View {
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 1) {
                    Text("menubar.banner.title".localized)
                        .font(.subheadline)
                    Text("menubar.banner.subtitle".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("menubar.banner.fix".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isHovering ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
