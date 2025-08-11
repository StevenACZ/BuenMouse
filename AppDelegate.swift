import Cocoa
import SwiftUI
import ServiceManagement

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
        setupStatusBar()
        setupComponents()
        eventMonitor?.requestPermissions()
        
        // Solo iniciar monitoring si está activo
        if settingsManager.isMonitoringActive {
            eventMonitor?.startMonitoring()
        }
        
        // Si está configurado para iniciar en menubar, ocultar ventana
        if settingsManager.startInMenubar {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.window?.orderOut(nil)
            }
        }
        
        // Verificar y sincronizar launch at login
        settingsManager.verifyLaunchAtLoginStatus()
        
        // Configurar apariencia
        settingsManager.setupAppearanceObserver()
        settingsManager.updateAppearance()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stopMonitoring()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "BuenMouse")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }
    
    private func setupComponents() {
        // Initialize handlers with optimized settings
        scrollHandler = ScrollHandler(settingsManager: settingsManager)
        gestureHandler = GestureHandler(settingsManager: settingsManager, scrollHandler: scrollHandler!)
        
        // Initialize event monitor
        eventMonitor = EventMonitor(gestureHandler: gestureHandler!, scrollHandler: scrollHandler!)
    }
    


    func moveToMenuBar() {
        window?.orderOut(nil)
    }

    func updateMonitoring(isActive: Bool) {
        if isActive {
            eventMonitor?.startMonitoring()
        } else {
            eventMonitor?.stopMonitoring()
        }
    }

    @objc private func statusItemClicked() {
        if let window = window {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
