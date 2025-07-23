import SwiftUI

@main
struct BuenMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var mainWindow: NSWindow?

    var body: some Scene {
        WindowGroup {
            ContentView(settings: appDelegate.settingsManager)
                .background(WindowAccessor(window: $mainWindow))
                .onChange(of: mainWindow) {
                    if let win = mainWindow {
                        appDelegate.window = win
                        // Configurar ventana para mejor rendimiento
                        win.titlebarAppearsTransparent = true
                        win.isMovableByWindowBackground = true
                        win.level = .normal
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}
