import SwiftUI

struct ContentView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BuenMouse")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Your productivity assistant")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("General Settings", systemImage: "gear")
                        .font(.headline)
                        .padding(.bottom, 12)

                    Toggle("Enable gesture monitoring", isOn: $settings.isMonitoringActive)
                        .animation(.default, value: settings.isMonitoringActive)

                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                        .animation(.default, value: settings.launchAtLogin)

                    Toggle("Start in menubar", isOn: $settings.startInMenubar)
                        .animation(.default, value: settings.startInMenubar)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Mouse & Drag", systemImage: "cursorarrow.motionlines")
                        .font(.headline)
                        .padding(.bottom, 12)

                    Toggle("Invert drag direction", isOn: $settings.invertDragDirection)
                        .animation(.default, value: settings.invertDragDirection)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Drag sensitivity: \(Int(settings.dragThreshold)) px")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Slider(value: $settings.dragThreshold, in: 20...1000, step: 10)
                            .animation(.default, value: settings.dragThreshold)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Scroll & Zoom", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                        .font(.headline)
                        .padding(.bottom, 12)

                    Toggle("Enable Ctrl + Scroll zoom", isOn: $settings.enableScrollZoom)
                        .animation(.default, value: settings.enableScrollZoom)

                    Toggle("Invert global scroll", isOn: $settings.invertScroll)
                        .animation(.default, value: settings.invertScroll)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zoom sensitivity: \(String(format: "%.1f", settings.zoomThreshold))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Slider(value: $settings.zoomThreshold, in: 0.5...5.0, step: 0.1)
                            .animation(.default, value: settings.zoomThreshold)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button {
                    settings.moveToMenuBar()
                } label: {
                    Label("Move to Menubar", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(BorderlessButtonStyle())

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
