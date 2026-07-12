import SwiftUI

/// The settings window: gesture showcase on top, general options below.
/// Every persistent option lives here — the menu bar panel stays quick.
struct SettingsView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var updateManager = UpdateManager.shared

    @State private var currentSlide: GesturePreviewType = .missionControl
    @State private var showResetConfirmation = false

    private var languageBinding: Binding<String> {
        Binding(
            get: { LocalizationManager.shared.language },
            set: { LocalizationManager.shared.language = $0 }
        )
    }

    private var isLastSlide: Bool {
        currentSlide == .spaceNavigation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            showcaseSection

            generalSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(width: 470)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("settings.reset.alert.title".localized, isPresented: $showResetConfirmation) {
            Button("settings.reset.alert.confirm".localized, role: .destructive) { settings.resetToDefaults() }
            Button("settings.reset.alert.cancel".localized, role: .cancel) {}
        } message: {
            Text("settings.reset.alert.message".localized)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BuenMouse")
                    .font(.system(size: 24, weight: .bold))
                Text("settings.subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {
                withAnimation(Theme.Anim.spring) { settings.isMonitoringActive.toggle() }
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(settings.isMonitoringActive ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    Text(
                        settings.isMonitoringActive
                            ? "settings.status.active".localized : "settings.status.paused".localized
                    )
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
                        .strokeBorder(
                            (settings.isMonitoringActive ? Color.green : Color.gray).opacity(0.25),
                            lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("settings.status.help".localized)
        }
    }

    // MARK: - Showcase

    /// Fixed-height region so the window never resizes while slides rotate.
    /// Short slides center vertically; the Space Navigation slide is taller
    /// (slider + invert), so it top-aligns and grows downward.
    private var showcaseSection: some View {
        VStack(spacing: 0) {
            if !isLastSlide { Spacer(minLength: 0) }
            GestureShowcase(settings: settings) { slide in
                withAnimation(Theme.Anim.slide) {
                    currentSlide = slide
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 264)
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(spacing: 0) {
            settingRow(
                icon: "power",
                title: "settings.launch_at_login.title".localized,
                subtitle: "settings.launch_at_login.subtitle".localized
            ) {
                Toggle("", isOn: $settings.launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .tint(Theme.accent)
            }

            Divider().padding(.horizontal, 14)

            settingRow(
                icon: "globe",
                title: "settings.language.title".localized,
                subtitle: "settings.language.subtitle".localized
            ) {
                Picker("", selection: languageBinding) {
                    Text("settings.language.english".localized).tag("en")
                    Text("settings.language.spanish".localized).tag("es")
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .labelsHidden()
                .fixedSize()
            }

            Divider().padding(.horizontal, 14)

            settingRow(
                icon: "arrow.down.circle",
                title: "settings.updates.title".localized,
                subtitle: "settings.updates.subtitle".localized
            ) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { updateManager.autoCheckEnabled },
                        set: { updateManager.setAutoCheckEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(Theme.accent)
            }

            Divider().padding(.horizontal, 14)

            settingRow(
                icon: "arrow.counterclockwise",
                title: "settings.reset.title".localized,
                subtitle: "settings.reset.subtitle".localized
            ) {
                Button("settings.reset.button".localized) { showResetConfirmation = true }
                    .controlSize(.small)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private func settingRow<Trailing: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#if DEBUG
    #Preview("Settings") {
        SettingsView(settings: PreviewSettings())
    }
#endif
