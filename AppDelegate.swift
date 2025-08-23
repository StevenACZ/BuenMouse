import Cocoa
import SwiftUI
import ServiceManagement
import os.log

enum WindowState {
    case hidden
    case visible
    case minimized
    case notInitialized
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: - Components
    let settingsManager = SettingsManager()
    private var eventMonitor: EventMonitor?
    private var gestureHandler: GestureHandler?
    private var scrollHandler: ScrollHandler?
    
    var window: NSWindow? {
        didSet {
            windowState = window != nil ? .hidden : .notInitialized
            os_log("Window reference updated: %{public}@", log: .default, type: .info, window != nil ? "Set" : "Cleared")
        }
    }
    private var statusItem: NSStatusItem?
    private var windowState: WindowState = .notInitialized

    override init() {
        super.init()
        settingsManager.appDelegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log("Application launching...", log: .default, type: .info)
        
        setupStatusBar()
        setupComponents()
        eventMonitor?.requestPermissions()
        
        // Solo iniciar monitoring si está activo
        if settingsManager.isMonitoringActive {
            eventMonitor?.startMonitoring()
        }
        
        // Configurar apariencia
        settingsManager.setupAppearanceObserver()
        settingsManager.updateAppearance()
        
        // Update status bar after settings are ready
        updateStatusBarIcon()
        
        // Verificar y sincronizar launch at login
        settingsManager.verifyLaunchAtLoginStatus()
        
        // Esperar a que la ventana esté completamente configurada
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.handleInitialWindowState()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stopMonitoring()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            updateStatusBarIcon()
            button.action = #selector(statusItemClicked)
            button.target = self
            
            // Add right-click menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Show Settings", action: #selector(statusItemClicked), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            
            let toggleItem = NSMenuItem(title: "Toggle Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "")
            toggleItem.target = self
            menu.addItem(toggleItem)
            
            menu.addItem(NSMenuItem.separator())
            let quitItem = NSMenuItem(title: "Quit BuenMouse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            menu.addItem(quitItem)
            
            statusItem?.menu = menu
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
        DispatchQueue.main.async {
            self.hideWindow()
        }
    }
    
    private func handleInitialWindowState() {
        guard let window = window else {
            os_log("Window not available for initial state setup", log: .default, type: .error)
            return
        }
        
        if settingsManager.startInMenubar {
            os_log("Hiding window for menubar start", log: .default, type: .info)
            hideWindow()
        } else {
            os_log("Showing window for normal start", log: .default, type: .info)
            showWindow()
        }
    }
    
    private func showWindow() {
        guard let window = window else {
            os_log("Cannot show window: window reference is nil", log: .default, type: .error)
            return
        }
        
        os_log("Showing window...", log: .default, type: .info)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        windowState = .visible
    }
    
    private func hideWindow() {
        guard let window = window else {
            os_log("Cannot hide window: window reference is nil", log: .default, type: .error)
            return
        }
        
        os_log("Hiding window...", log: .default, type: .info)
        window.orderOut(nil)
        windowState = .hidden
    }

    func updateMonitoring(isActive: Bool) {
        if isActive {
            eventMonitor?.startMonitoring()
        } else {
            eventMonitor?.stopMonitoring()
        }
        updateStatusBarIcon()
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        
        let iconName: String
        let tooltip: String
        
        if settingsManager.isMonitoringActive {
            iconName = "cursorarrow"
            tooltip = "BuenMouse: Active - Click to show settings"
        } else {
            iconName = "cursorarrow.slash"
            tooltip = "BuenMouse: Inactive - Click to show settings"
        }
        
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "BuenMouse")
        button.toolTip = tooltip
        
        // Update menu item text
        if let menu = statusItem?.menu,
           let toggleItem = menu.item(withTitle: "Toggle Monitoring") {
            toggleItem.title = settingsManager.isMonitoringActive ? "Disable Monitoring" : "Enable Monitoring"
        }
    }
    
    @objc private func toggleMonitoring() {
        settingsManager.isMonitoringActive.toggle()
        os_log("Monitoring toggled via status bar: %{public}@", log: .default, type: .info, settingsManager.isMonitoringActive ? "enabled" : "disabled")
    }

    @objc private func statusItemClicked() {
        // Check if right-click or left-click
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            return // Let the menu handle right-clicks
        }
        
        os_log("Status bar clicked - Current state: %{public}@", log: .default, type: .info, String(describing: windowState))
        
        guard let window = window else {
            os_log("Status bar clicked but window is nil", log: .default, type: .error)
            return
        }
        
        DispatchQueue.main.async {
            switch self.windowState {
            case .visible:
                self.hideWindow()
            case .hidden, .minimized, .notInitialized:
                self.showWindow()
            }
        }
    }
}
