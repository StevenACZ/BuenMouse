import SwiftUI

/// Standalone About panel — opened from the menu bar dropdown.
/// Kept out of the main settings window so the settings stay focused
/// on the gesture showcase.
struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            // App icon + name + version
            VStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.22), radius: 8, y: 3)

                VStack(spacing: 3) {
                    Text("BuenMouse")
                        .font(.system(size: 22, weight: .bold))
                    Text("Version \(version)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("by Steven Coaila Zaa")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 8)

            Text("Advanced mouse gestures and productivity tools for macOS. Open source and privacy-focused.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            HStack(spacing: 10) {
                linkButton(label: "GitHub", systemImage: "chevron.left.forwardslash.chevron.right",
                           url: "https://github.com/StevenACZ/BuenMouse")
                linkButton(label: "Report Issue", systemImage: "exclamationmark.bubble",
                           url: "https://github.com/StevenACZ/BuenMouse/issues/new")
            }

            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                Text("MIT License")
                Text("·")
                Text("Made on macOS")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 4)
        }
        .padding(24)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func linkButton(label: String, systemImage: String, url: String) -> some View {
        Button(action: { open(url) }) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
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

#if DEBUG
#Preview { AboutView() }
#endif
