import SwiftUI

struct ContentView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "cursorarrow.and.square.on.square.dashed")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
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

            VStack(alignment: .leading, spacing: 8) {
                Label("General Settings", systemImage: "gear")
                    .font(.headline)

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enable gesture monitoring", isOn: $settings.isMonitoringActive)
                        Toggle("Launch at login", isOn: $settings.launchAtLogin)
                        Toggle("Start in menubar", isOn: $settings.startInMenubar)
                        Toggle("Invert drag direction", isOn: $settings.invertDragDirection)
                        Toggle("Invert global scroll", isOn: $settings.invertScroll)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Drag sensitivity: \(Int(settings.dragThreshold)) px")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Slider(value: $settings.dragThreshold, in: 20...1000, step: 10)
                        }
                    }
                    .padding(12)
                }
            }

            HStack {
                Button {
                    settings.moveToMenuBar()
                } label: {
                    Label("Move to Menubar", systemImage: "arrow.up.right.square")
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400, height: 440)
    }
}
