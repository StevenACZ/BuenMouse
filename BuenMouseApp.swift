import SwiftUI
import os.log

@main
struct BuenMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var mainWindow: NSWindow?

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(settings: appDelegate.settingsManager)
                .background(WindowAccessor(window: $mainWindow))
                .onChange(of: mainWindow) {
                    setupWindow()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 600)
    }

    private func setupWindow() {
        guard let win = mainWindow else {
            os_log("Window setup called but mainWindow is nil", log: .default, type: .error)
            return
        }

        os_log("Setting up main window...", log: .default, type: .info)

        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.level = .normal
        win.backgroundColor = NSColor.controlBackgroundColor
        win.collectionBehavior = [.managed, .participatesInCycle]
        win.isRestorable = false

        self.appDelegate.window = win
        os_log("Window assigned to AppDelegate", log: .default, type: .info)
    }
}
