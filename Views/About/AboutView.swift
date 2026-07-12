import SwiftUI

/// Standalone About panel — opened from the menu bar dropdown.
/// Kept out of the main settings window so the settings stay focused
/// on the gesture showcase.
struct AboutView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var updateManager = UpdateManager.shared

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var copyrightYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    private let accent: Color = Theme.accent

    var body: some View {
        VStack(spacing: 18) {
            heroSection
            taglineSection
            featureChipsSection
            divider
            linksSection
            footerSection
        }
        .padding(.horizontal, 26)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .background(backgroundLayer)
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                .shadow(color: accent.opacity(0.35), radius: 10, y: 5)

            VStack(spacing: 2) {
                Text("BuenMouse")
                    .font(.system(size: 24, weight: .bold))

                HStack(spacing: 6) {
                    Text("about.version".localized(version))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("about.build".localized(build))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                updateStatus
                    .padding(.top, 4)
            }
        }
    }

    /// Update capsule mirroring `UpdateManager.phase`, plus a manual
    /// "check for updates" affordance when nothing is pending.
    @ViewBuilder
    private var updateStatus: some View {
        switch updateManager.phase {
        case .idle:
            checkForUpdatesButton

        case .available(let version):
            VStack(spacing: 5) {
                Button {
                    updateManager.installPendingUpdate()
                } label: {
                    updateCapsule(
                        icon: "arrow.down.circle",
                        text: "about.update.install".localized(version)
                    )
                }
                .buttonStyle(.plain)

                if updateManager.releasePageURL != nil {
                    Button {
                        updateManager.openReleasePage()
                    } label: {
                        Text("about.update.release_notes".localized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }

        case .downloading(let fraction):
            updateProgressCapsule(
                text: "about.update.downloading".localized
                    + (fraction.map { " \(Int($0 * 100))%" } ?? ""))

        case .installing:
            updateProgressCapsule(text: "about.update.installing".localized)

        case .failed:
            Button {
                updateManager.installPendingUpdate()
            } label: {
                updateCapsule(
                    icon: "exclamationmark.arrow.circlepath",
                    text: "about.update.retry".localized
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var checkForUpdatesButton: some View {
        switch updateManager.manualCheckStatus {
        case .checking:
            HStack(spacing: 5) {
                ProgressView()
                    .controlSize(.mini)
                Text("about.update.check".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .upToDate:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                Text("about.update.up_to_date".localized)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(accent)
        case .idle:
            Button {
                updateManager.checkForUpdatesManually()
            } label: {
                Text("about.update.check".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline()
            }
            .buttonStyle(.plain)
        }
    }

    private func updateCapsule(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)

            Text(text)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(accent.opacity(0.12)))
        .overlay(Capsule().strokeBorder(accent.opacity(0.22), lineWidth: 1))
        .foregroundStyle(accent)
    }

    private func updateProgressCapsule(text: String) -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)

            Text(text)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(accent.opacity(0.12)))
        .overlay(Capsule().strokeBorder(accent.opacity(0.22), lineWidth: 1))
        .foregroundStyle(accent)
    }

    private var taglineSection: some View {
        Text("about.tagline".localized)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    private var featureChipsSection: some View {
        HStack(spacing: 8) {
            featureChip(icon: "rectangle.3.group", text: "about.chip.mission_control".localized)
            featureChip(icon: "rectangle.split.3x1", text: "about.chip.spaces".localized)
            featureChip(icon: "plus.magnifyingglass", text: "about.chip.zoom".localized)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: 1)
            .padding(.horizontal, 6)
    }

    private var linksSection: some View {
        HStack(spacing: 10) {
            linkButton(
                label: "about.link.github".localized,
                systemImage: "chevron.left.forwardslash.chevron.right",
                url: "https://github.com/StevenACZ/BuenMouse")
            linkButton(
                label: "about.link.report_issue".localized,
                systemImage: "exclamationmark.bubble",
                url: "https://github.com/StevenACZ/BuenMouse/issues/new")
        }
    }

    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("about.made_by".localized)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 9))
                Text("about.license".localized)
                Text("·")
                Text("© \(copyrightYear)")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Builders

    private func featureChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(accent.opacity(0.12)))
        .overlay(Capsule().strokeBorder(accent.opacity(0.22), lineWidth: 1))
    }

    private func linkButton(label: String, systemImage: String, url: String) -> some View {
        Button(action: { open(url) }) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(url)
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(0.55),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

#if DEBUG
    #Preview { AboutView() }
#endif
