import SwiftUI

// MARK: - Main Content View
struct ContentView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                GestureShowcase(settings: settings)

                Divider()
                    .padding(.vertical, 4)

                AboutSection()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .frame(minWidth: 450, idealWidth: 450, maxWidth: 450,
               minHeight: 650, idealHeight: 650, maxHeight: 650)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BuenMouse")
                    .font(.system(size: 24, weight: .bold))
                Text("Mouse gestures for macOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { settings.isMonitoringActive.toggle() }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(settings.isMonitoringActive ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    Text(settings.isMonitoringActive ? "Active" : "Inactive")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(settings.isMonitoringActive ? .green : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill((settings.isMonitoringActive ? Color.green : Color.gray).opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .strokeBorder((settings.isMonitoringActive ? Color.green : Color.gray).opacity(0.25),
                                      lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Click to toggle gesture monitoring")
        }
    }
}

// MARK: - About Section

private struct AboutSection: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    }

    var body: some View {
        VStack(spacing: 14) {
            // Hero
            HStack(alignment: .center, spacing: 14) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("BuenMouse")
                        .font(.system(size: 18, weight: .bold))
                    Text("Version \(version)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("by Steven Coaila Zaa")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            // Tagline
            Text("Advanced mouse gestures and productivity tools for macOS. Open source and privacy-focused.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            // Links
            HStack(spacing: 10) {
                linkButton(label: "GitHub", systemImage: "chevron.left.forwardslash.chevron.right",
                           url: "https://github.com/StevenACZ/BuenMouse")
                linkButton(label: "Report Issue", systemImage: "exclamationmark.bubble",
                           url: "https://github.com/StevenACZ/BuenMouse/issues/new")
            }

            // Footer
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                Text("MIT License")
                Text("·")
                Text("Made on macOS")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private func linkButton(label: String, systemImage: String, url: String) -> some View {
        Button(action: { open(url) }) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(url)
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
