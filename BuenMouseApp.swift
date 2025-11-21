import SwiftUI
import os.log

@main
struct BuenMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var mainWindow: NSWindow?
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(settings: appDelegate.settingsManager)
                .background(WindowAccessor(window: $mainWindow))
                .onChange(of: mainWindow) {
                    setupWindow()
                }
                .onAppear {
                    // Force window creation on first appearance
                    os_log("ContentView appeared - window should be created", log: .default, type: .info)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 600)
        .commands {
            // This ensures WindowGroup is properly registered
            CommandGroup(replacing: .newItem) { }
        }
    }
    
    private func setupWindow() {
        guard let win = mainWindow else {
            os_log("Window setup called but mainWindow is nil", log: .default, type: .error)
            return
        }
        
        os_log("Setting up main window...", log: .default, type: .info)
        
        // Configurar ventana para mejor rendimiento y usabilidad
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.level = .normal
        win.backgroundColor = NSColor.controlBackgroundColor
        
        // Optimizar configuraciones de ventana
        win.collectionBehavior = [.managed, .participatesInCycle]
        win.isRestorable = false

        // Asignar al AppDelegate directamente - we're already on main thread
        self.appDelegate.window = win
        os_log("Window reference assigned to AppDelegate", log: .default, type: .info)
    }
}
