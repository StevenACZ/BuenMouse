import SwiftUI

// MARK: - Main Content View
struct ContentView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                Divider()

                // General Settings
                generalSettingsSection

                Divider()

                // Gesture Settings
                gestureSettingsSection

                Divider()

                // Scroll Settings
                scrollSettingsSection

                Divider()

                // Appearance Settings
                appearanceSettingsSection

                Divider()

                // About Section
                aboutSection

                Spacer(minLength: 20)

                // Reset to Defaults
                resetSection

                // Action Buttons
                actionButtonsSection
            }
            .padding(32)
        }
        .frame(minWidth: 600, idealWidth: 700, maxWidth: 900,
               minHeight: 500, idealHeight: 600, maxHeight: 800)
        .onAppear {
            setupKeyboardShortcuts()
        }
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ESC key
            if event.keyCode == 53 {
                settings.moveToMenuBar()
                return nil
            }
            // CMD+W
            if event.keyCode == 13 && event.modifierFlags.contains(.command) {
                settings.moveToMenuBar()
                return nil
            }
            return event
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("BuenMouse Settings")
                    .font(.system(size: 28, weight: .bold))
                Text("Configure your mouse gestures and preferences")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Monitoring Status Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(settings.isMonitoringActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(settings.isMonitoringActive ? "Active" : "Inactive")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(settings.isMonitoringActive ? .green : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(settings.isMonitoringActive ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
            )
        }
    }

    // MARK: - General Settings
    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.headline)
                .foregroundColor(.blue)

            Toggle(isOn: $settings.isMonitoringActive) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Gesture Monitoring")
                        .font(.body)
                    Text("Master switch for all gesture features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .help("Turn on/off all mouse gesture recognition")

            Toggle(isOn: $settings.launchAtLogin) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch at Login")
                        .font(.body)
                    Text("Start automatically when you log in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let error = settings.launchAtLoginError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Button("Retry") {
                        settings.updateLaunchAtLogin(settings.launchAtLogin)
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
                .padding(.leading, 20)
            }

            Toggle(isOn: $settings.startInMenubar) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start in Menu Bar")
                        .font(.body)
                    Text("Hide window on startup")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Gesture Settings
    private var gestureSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gestures & Navigation")
                .font(.headline)
                .foregroundColor(.purple)

            Toggle(isOn: $settings.enableMissionControl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Mission Control")
                        .font(.body)
                    Text("Middle click to activate Mission Control")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!settings.isMonitoringActive)
            .help("Press middle mouse button to open Mission Control")

            Toggle(isOn: $settings.enableSpaceNavigation) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Space Navigation")
                        .font(.body)
                    Text("Middle drag to switch between spaces")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!settings.isMonitoringActive)
            .help("Hold middle mouse button and drag horizontally to switch spaces")

            Toggle(isOn: $settings.invertDragDirection) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invert Drag Direction")
                        .font(.body)
                    Text("Reverse horizontal drag behavior")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!settings.isMonitoringActive || !settings.enableSpaceNavigation)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Drag Sensitivity")
                        .font(.body)
                    Spacer()
                    Text("\(Int(settings.dragThreshold)) px")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Slider(value: $settings.dragThreshold, in: 0...500, step: 5)
                    .disabled(!settings.isMonitoringActive || !settings.enableSpaceNavigation)

                Text("Higher values require more movement to trigger")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 20)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Scroll Settings
    private var scrollSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scroll & Zoom")
                .font(.headline)
                .foregroundColor(.green)

            Toggle(isOn: $settings.enableScrollZoom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Ctrl + Scroll Zoom")
                        .font(.body)
                    Text("Use Control + scroll wheel to zoom in/out")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!settings.isMonitoringActive)
            .help("Hold Control key and scroll to zoom in/out")

            if settings.enableScrollZoom {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Hold ⌃ Control and scroll to zoom")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 20)
            }

            Toggle(isOn: $settings.invertScroll) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invert Scroll Direction")
                        .font(.body)
                    Text("Natural scrolling for mouse wheel")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!settings.isMonitoringActive)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Appearance Settings
    private var appearanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance")
                .font(.headline)
                .foregroundColor(.orange)

            Toggle(isOn: $settings.followSystemAppearance) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Follow System Appearance")
                        .font(.body)
                    Text("Automatically match system light/dark mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !settings.followSystemAppearance {
                Toggle(isOn: $settings.isDarkMode) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dark Mode")
                            .font(.body)
                        Text("Use dark theme")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.headline)
                .foregroundColor(.indigo)

            HStack(spacing: 16) {
                // App Logo
                Image("AppLogo")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("BuenMouse")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Version 2.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Created by Steven Coaila Zaa")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Text("Advanced mouse gestures and productivity tools for macOS. Open source and privacy-focused.")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Links
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "https://github.com/StevenACZ/BuenMouse") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                        Text("GitHub Repository")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.borderless)

                Text("•")
                    .foregroundColor(.secondary)

                Text("MIT License")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Reset Section
    private var resetSection: some View {
        Button(action: {
            settings.resetToDefaults()
        }) {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset All Settings to Defaults")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.orange)
        .help("Restore all settings to their default values")
    }

    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            Button(action: {
                settings.moveToMenuBar()
            }) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Move to Menu Bar")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit BuenMouse")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.red)
        }
    }
}
