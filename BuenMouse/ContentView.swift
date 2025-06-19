import SwiftUI

// La vista espera un objeto que cumpla con SettingsProtocol
struct ContentView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Cabecera
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "cursorarrow.and.square.on.square.dashed")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BuenMouse")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Tu asistente de productividad.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Ajustes
            VStack(alignment: .leading, spacing: 20) {
                Label("Ajustes Generales", systemImage: "gear")
                    .font(.headline)
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Activar monitoreo de gestos", isOn: $settings.isMonitoringActive)
                        Toggle("Abrir BuenMouse al iniciar sesión", isOn: $settings.launchAtLogin)
                        Toggle("Iniciar directamente en la barra de menús", isOn: $settings.startInMenubar)
                        Toggle("Invertir dirección de arrastre", isOn: $settings.invertDragDirection)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sensibilidad de arrastre: \(Int(settings.dragThreshold)) px")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Slider(value: $settings.dragThreshold, in: 20...1000, step: 10)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }

            HStack {
                Button {
                    settings.moveToMenuBar()
                } label: {
                    Label("Mover a la Barra de Menús", systemImage: "arrow.up.right.square")
                }

                Spacer()

                Button("Salir") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 28)
        .frame(width: 400, height: 440)
    }
}
