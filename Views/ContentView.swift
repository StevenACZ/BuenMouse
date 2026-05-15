import SwiftUI

// MARK: - Main Content View
struct ContentView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings
    @State private var currentSlide: GesturePreviewType = .missionControl

    private var isLastSlide: Bool {
        currentSlide == .spaceNavigation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            // Short slides (Mission Control, Scroll Zoom, Invert Scroll) get
            // vertically centered in the remaining space. The last slide
            // (Space Navigation) is taller because of the slider extras, so
            // we top-align it instead — letting it grow downward without
            // feeling cramped.
            if isLastSlide {
                Spacer().frame(height: 12)
                GestureShowcase(settings: settings) { slide in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentSlide = slide
                    }
                }
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                GestureShowcase(settings: settings) { slide in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentSlide = slide
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .frame(minWidth: 450, idealWidth: 450, maxWidth: 450,
               minHeight: 340, idealHeight: 340, maxHeight: 340)
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
