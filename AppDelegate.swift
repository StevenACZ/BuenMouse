import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: - Components
    let settingsManager = SettingsManager()
    private var eventMonitor: EventMonitor?
    private var gestureHandler: GestureHandler?
    private var scrollHandler: ScrollHandler?
    
    var window: NSWindow?
    private var statusItem: NSStatusItem?

    override init() {
        super.init()
        settingsManager.appDelegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupComponents()
        eventMonitor?.requestPermissions()
        eventMonitor?.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stopMonitoring()
    }
    
    private func setupComponents() {
        // Initialize handlers
        scrollHandler = ScrollHandler(settingsManager: settingsManager)
        gestureHandler = GestureHandler(settingsManager: settingsManager, scrollHandler: scrollHandler!)
        
        // Initialize event monitor
        eventMonitor = EventMonitor(gestureHandler: gestureHandler!, scrollHandler: scrollHandler!)
    }

    func moveToMenuBar() {
        print("moveToMenuBar called")
        // Crear el status item si no existe
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "BuenMouse")
                button.action = #selector(statusItemClicked)
                button.target = self
            }
        }
        // Ocultar la ventana principal
        window?.orderOut(nil)
    }

    @objc private func statusItemClicked() {
        print("statusItemClicked called")
        // Mostrar la ventana principal y traerla al frente
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
