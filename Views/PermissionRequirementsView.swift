import SwiftUI
import Combine

/// Compact, single-permission onboarding view. Polls the accessibility
/// status every 1.5s and on `didBecomeActive` so it auto-dismisses the
/// moment the user grants permission.
struct PermissionRequirementsView: View {
    static let windowSize = CGSize(width: 480, height: 230)

    let onActivate: () -> Void
    let onClose: () -> Void

    @State private var isGranted: Bool = AccessibilityPermission.isGranted
    @Environment(\.colorScheme) private var colorScheme
    private let refreshTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private let accent: Color = .blue

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(alignment: .leading, spacing: 0) {
                header

                Spacer(minLength: 10)

                if isGranted {
                    successCard
                } else {
                    permissionCard
                }

                Spacer(minLength: 10)

                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .onAppear { refresh() }
        .onReceive(refreshTimer) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("AppLogo")
                .resizable()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .shadow(color: accent.opacity(0.35), radius: 5, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("Welcome to BuenMouse")
                    .font(.system(size: 17, weight: .bold))

                Text("One quick permission and you're ready to go.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "clock")
                .font(.system(size: 10, weight: .semibold))
            Text(isGranted ? "Active" : "Pending")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(isGranted ? Color.green : accent)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule().fill((isGranted ? Color.green : accent).opacity(0.14))
        )
    }

    private var permissionCard: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 46, height: 46)

                Image(systemName: "accessibility")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Accessibility")
                    .font(.system(size: 14, weight: .semibold))

                Text("BuenMouse needs Accessibility access to detect mouse clicks and gestures.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onActivate) {
                Text("Activate")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(accent))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(accent: accent))
    }

    private var successCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 3) {
                Text("You're all set!")
                    .font(.system(size: 14, weight: .semibold))
                Text("Accessibility access is active. You can start using BuenMouse.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(cardBackground(accent: .green))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "hand.point.up.left.fill")
                    .font(.system(size: 11))
                Text(isGranted ? "Ready to go" : "Click Activate, then drop BuenMouse on the list.")
                    .font(.caption)
            }
            .foregroundStyle(isGranted ? Color.green : Color.secondary)

            Spacer()

            if isGranted {
                Button("Continue", action: onClose)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            } else {
                Button("Later", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Helpers

    private func cardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.85 : 1))
            .overlay(
                LinearGradient(
                    colors: [accent.opacity(colorScheme == .dark ? 0.14 : 0.07), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent.opacity(colorScheme == .dark ? 0.25 : 0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 10, y: 4)
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.42 : 0.72),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func refresh() {
        let current = AccessibilityPermission.isGranted
        if current != isGranted {
            withAnimation(.easeInOut(duration: 0.3)) { isGranted = current }
        }
    }
}

#if DEBUG
#Preview("Pending") {
    PermissionRequirementsView(onActivate: {}, onClose: {})
}
#endif
