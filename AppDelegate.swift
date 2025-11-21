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
            os_log("Window reference updated: %{public}@", log: .default, type: .info, window != nil ? "Set" : "Cleared")

            // Handle initial window state with delay to ensure window is fully initialized
            if let win = window {
                // Give SwiftUI time to fully initialize the window
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.handleInitialWindowState(for: win)
                }
            } else {
                windowState = .notInitialized
            }
        }
    }
    private var statusItem: NSStatusItem?
    private var windowState: WindowState = .notInitialized
    private var isInitialSetupDone = false

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

        // Note: handleInitialWindowState() is now called from window's didSet
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
            
            let toggleItem = NSMenuItem(title: settingsManager.isMonitoringActive ? "Disable Monitoring" : "Enable Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "")
            toggleItem.target = self
            toggleItem.tag = 999 // Unique tag to find it later
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
    
    private func handleInitialWindowState(for win: NSWindow) {
        guard !isInitialSetupDone else {
            os_log("Initial setup already done, skipping", log: .default, type: .info)
            return
        }

        isInitialSetupDone = true

        os_log("Setting up initial window state - startInMenubar: %{public}@",
               log: .default, type: .info,
               settingsManager.startInMenubar ? "YES" : "NO")

        if settingsManager.startInMenubar {
            // Start hidden - don't show the window at all
            os_log("Starting in menubar - keeping window hidden", log: .default, type: .info)
            windowState = .hidden
            // Don't call hideWindow() - just don't show it
            win.orderOut(nil)
        } else {
            // Start visible - show the window
            os_log("Starting visible - showing window", log: .default, type: .info)
            showWindow()
        }
    }
    
    private func showWindow() {
        guard let window = window else {
            os_log("Cannot show window: window reference is nil", log: .default, type: .error)
            return
        }

        os_log("Showing window - current state: visible=%{public}@, miniaturized=%{public}@, level=%ld",
               log: .default, type: .info,
               window.isVisible ? "YES" : "NO",
               window.isMiniaturized ? "YES" : "NO",
               window.level.rawValue)

        // Restore if miniaturized
        if window.isMiniaturized {
            os_log("Deminiaturizing window", log: .default, type: .info)
            window.deminiaturize(nil)
        }

        // Ensure window level is normal
        window.level = .normal

        // Force window to front using multiple methods
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Activate app - CRITICAL for visibility after login
        NSApp.activate(ignoringOtherApps: true)

        // Update state
        windowState = .visible

        // Verify after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if window.isVisible {
                os_log("✅ Window shown successfully and verified visible", log: .default, type: .info)
            } else {
                os_log("⚠️ Warning: Window not visible after show attempt, retrying...", log: .default, type: .error)
                // Retry once
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
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

        // Animate icon change with bounce effect
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            // Scale down
            button.animator().alphaValue = 0.5
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                // Scale back up
                button.animator().alphaValue = 1.0
            })
        })

        // Update menu item text using tag
        if let menu = statusItem?.menu,
           let toggleItem = menu.item(withTag: 999) {
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

        // Always try to recover window reference if lost
        if window == nil {
            os_log("Window reference is nil, attempting recovery...", log: .default, type: .error)

            // Try multiple strategies to find the window
            let allWindows = NSApp.windows
            os_log("Found %d windows in app", log: .default, type: .info, allWindows.count)

            // Strategy 1: Find by ContentView type
            window = allWindows.first { win in
                guard let contentView = win.contentView else { return false }
                let className = String(describing: type(of: contentView))
                os_log("Checking window with contentView: %{public}@", log: .default, type: .info, className)
                return className.contains("NSHostingView") && win.title == ""
            }

            // Strategy 2: If still not found, take the first window
            if window == nil && !allWindows.isEmpty {
                window = allWindows.first
                os_log("Using first available window as fallback", log: .default, type: .info)
            }

            if window != nil {
                os_log("Window reference recovered successfully", log: .default, type: .info)
            }
        }

        guard let win = window else {
            os_log("ERROR: No window found - cannot show settings", log: .default, type: .error)
            return
        }

        // Toggle window visibility
        if windowState == .visible && win.isVisible {
            os_log("Hiding window", log: .default, type: .info)
            hideWindow()
        } else {
            os_log("Showing window", log: .default, type: .info)
            showWindow()
        }
    }
}
