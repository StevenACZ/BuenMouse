import SwiftUI

/// Bridge between the AppKit popover and the SwiftUI panel. Rebuilt on every
/// open so permission state is always current; `fixedSize` lets the hosting
/// controller measure the true content height.
struct MenuBarPanelHost: View {
    @ObservedObject var settings: SettingsManager
    let isPermissionGranted: Bool
    let openSettings: () -> Void
    let openAbout: () -> Void
    let openPermissions: () -> Void
    let quit: () -> Void

    var body: some View {
        MenuBarView(
            settings: settings,
            isPermissionGranted: isPermissionGranted,
            openSettings: openSettings,
            openAbout: openAbout,
            openPermissions: openPermissions,
            quit: quit
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The dropdown panel: header with master switch, a visual 2×2 gesture grid,
/// and the Settings / About / Quit rows.
struct MenuBarView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings
    let isPermissionGranted: Bool
    let openSettings: () -> Void
    let openAbout: () -> Void
    let openPermissions: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            if !isPermissionGranted {
                PermissionBanner(action: openPermissions)
                Divider()
            }

            gestureGrid
                .padding(12)

            Divider()
                .padding(.horizontal, 12)

            ActionRow(
                icon: "gearshape",
                title: "Settings",
                subtitle: "Gestures, drag distance, launch at login",
                action: openSettings
            )

            Divider().padding(.horizontal, 16)

            ActionRow(icon: "info.circle", title: "About BuenMouse", action: openAbout)

            Divider().padding(.horizontal, 16)

            ActionRow(icon: "power", title: "Quit BuenMouse", isDestructive: true, action: quit)
                .padding(.bottom, 4)
        }
        .frame(width: Theme.Layout.panelWidth)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var enabledCount: Int {
        [
            settings.enableMissionControl,
            settings.enableSpaceNavigation,
            settings.enableScrollZoom,
            settings.invertScroll,
        ].filter { $0 }.count
    }

    private var statusLine: String {
        if !isPermissionGranted { return "Accessibility access needed" }
        if !settings.isMonitoringActive { return "Gestures paused" }
        return "\(enabledCount) of \(GesturePreviewType.allCases.count) gestures on"
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image("AppLogo")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("BuenMouse")
                    .font(.headline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .animation(Theme.Anim.easeOut, value: statusLine)

            Spacer()

            Toggle("", isOn: $settings.isMonitoringActive)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(Theme.accent)
                .disabled(!isPermissionGranted)
                .help(settings.isMonitoringActive ? "Pause all gestures" : "Resume gestures")
        }
    }

    // MARK: - Gesture Grid

    private var gestureGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForEach(GesturePreviewType.allCases, id: \.self) { type in
                GestureTile(
                    type: type,
                    isOn: binding(for: type).wrappedValue,
                    isEnabled: settings.isMonitoringActive && isPermissionGranted
                ) {
                    withAnimation(Theme.Anim.spring) {
                        binding(for: type).wrappedValue.toggle()
                    }
                }
            }
        }
    }

    private func binding(for type: GesturePreviewType) -> Binding<Bool> {
        switch type {
        case .missionControl: return $settings.enableMissionControl
        case .spaceNavigation: return $settings.enableSpaceNavigation
        case .scrollZoom: return $settings.enableScrollZoom
        case .invertScroll: return $settings.invertScroll
        }
    }
}

// MARK: - Gesture Tile

private struct GestureTile: View {
    let type: GesturePreviewType
    let isOn: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOn ? type.accent : Color.secondary)
                    .frame(height: 20)

                Text(type.shortTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOn ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? type.accent.opacity(0.12) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isOn ? type.accent.opacity(0.35) : Color.secondary.opacity(0.12),
                        lineWidth: 1)
            )
            .scaleEffect(isHovering && isEnabled ? 1.02 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.Anim.easeOut) { isHovering = hovering }
        }
        .opacity(isEnabled ? 1 : 0.45)
        .disabled(!isEnabled)
        .animation(Theme.Anim.spring, value: isOn)
        .help(isOn ? "Disable \(type.shortTitle)" : "Enable \(type.shortTitle)")
    }
}

#if DEBUG
    #Preview("Panel") {
        MenuBarView(
            settings: PreviewSettings(),
            isPermissionGranted: true,
            openSettings: {}, openAbout: {}, openPermissions: {}, quit: {}
        )
    }

    #Preview("Panel — no permission") {
        MenuBarView(
            settings: PreviewSettings(),
            isPermissionGranted: false,
            openSettings: {}, openAbout: {}, openPermissions: {}, quit: {}
        )
    }
#endif
