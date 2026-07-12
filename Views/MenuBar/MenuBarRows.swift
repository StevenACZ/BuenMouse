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

/// Update lifecycle row: pending update → one-click install with inline
/// download/install progress; a failed install offers a retry.
struct UpdateMenuRow: View {
    @ObservedObject var manager: UpdateManager

    var body: some View {
        switch manager.phase {
        case .idle:
            EmptyView()

        case .available(let version):
            ActionRow(
                icon: "arrow.down.circle",
                title: "menubar.update.available".localized,
                subtitle: "menubar.update.install_hint".localized(version)
            ) {
                manager.installPendingUpdate()
            }

        case .downloading(let fraction):
            UpdateProgressRow(
                title: "menubar.update.downloading".localized,
                subtitle: fraction.map { "\(Int($0 * 100))%" },
                fraction: fraction
            )

        case .installing:
            UpdateProgressRow(
                title: "menubar.update.installing".localized,
                subtitle: "menubar.update.relaunch".localized,
                fraction: nil
            )

        case .failed:
            ActionRow(
                icon: "exclamationmark.arrow.circlepath",
                title: "menubar.update.failed".localized,
                subtitle: "menubar.update.retry_hint".localized
            ) {
                manager.installPendingUpdate()
            }
        }
    }
}

/// Non-interactive progress row shown while an update downloads or installs.
struct UpdateProgressRow: View {
    let title: String
    let subtitle: String?
    let fraction: Double?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let fraction {
                    ProgressView(value: fraction)
                        .progressViewStyle(.circular)
                } else {
                    ProgressView()
                }
            }
            .controlSize(.small)
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
