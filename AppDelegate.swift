import Cocoa
import SwiftUI
import os.log

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: - Components
    let settingsManager = SettingsManager()
    private var eventMonitor: EventMonitor?
    private var gestureHandler: GestureHandler?
    private var scrollHandler: ScrollHandler?

    // MARK: - Status Bar
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?

    override init() {
        super.init()
        settingsManager.appDelegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check for login item simulation mode
        let simulateLoginItem = CommandLine.arguments.contains("-simulateLoginItem")
        os_log("Application launching... (simulateLoginItem: %{public}@)", log: .default, type: .info, simulateLoginItem ? "YES" : "NO")
        os_log("NSApp.windows.count at launch: %d", log: .default, type: .info, NSApp.windows.count)

        // Register for launch at login
        _ = ServiceManager.register()

        setupComponents()
        setupStatusBar()
        eventMonitor?.requestPermissions()

        if settingsManager.isMonitoringActive {
            eventMonitor?.startMonitoring()
        }

        settingsManager.setupAppearanceObserver()
        settingsManager.updateAppearance()

        // Hide window by default after a short delay to let it initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            os_log("After 0.1s delay - NSApp.windows.count: %d, mainWindow: %{public}@",
                   log: .default, type: .info,
                   NSApp.windows.count,
                   self?.mainWindow == nil ? "NIL" : "EXISTS")
            self?.hideWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window is closed - menu bar app behavior
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Only show window if there's no visible window already
        if !flag {
            showWindow()
        }
        return true
    }

    private func setupComponents() {
        scrollHandler = ScrollHandler(settingsManager: settingsManager)
        gestureHandler = GestureHandler(settingsManager: settingsManager, scrollHandler: scrollHandler!)
        eventMonitor = EventMonitor(gestureHandler: gestureHandler!, scrollHandler: scrollHandler!)
    }

    // MARK: - Status Bar Setup
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateStatusBarIcon()

        // Create the dropdown menu
        let menu = NSMenu()

        // Show Settings
        let showSettingsItem = NSMenuItem(title: "Show Settings", action: #selector(showSettingsClicked), keyEquivalent: "")
        showSettingsItem.target = self
        menu.addItem(showSettingsItem)

        menu.addItem(NSMenuItem.separator())

        // Gesture Monitoring Toggle
        let monitoringItem = NSMenuItem(title: "Gesture Monitoring", action: #selector(toggleMonitoringClicked), keyEquivalent: "")
        monitoringItem.target = self
        monitoringItem.state = settingsManager.isMonitoringActive ? .on : .off
        menu.addItem(monitoringItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit BuenMouse", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func showSettingsClicked() {
        os_log("Show Settings clicked", log: .default, type: .info)
        showWindow()
    }

    @objc private func toggleMonitoringClicked() {
        settingsManager.isMonitoringActive.toggle()

        // Update menu item state
        if let menu = statusItem?.menu,
           let monitoringItem = menu.item(withTitle: "Gesture Monitoring") {
            monitoringItem.state = settingsManager.isMonitoringActive ? .on : .off
        }

        // Update icon
        updateStatusBarIcon()

        // Start/stop monitoring
        if settingsManager.isMonitoringActive {
            eventMonitor?.startMonitoring()
        } else {
            eventMonitor?.stopMonitoring()
        }

        os_log("Monitoring toggled: %{public}@", log: .default, type: .info,
               settingsManager.isMonitoringActive ? "ON" : "OFF")
    }

    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Window Management
    func setMainWindow(_ window: NSWindow?) {
        os_log("setMainWindow called: %{public}@", log: .default, type: .info, window == nil ? "NIL" : "WINDOW SET")
        self.mainWindow = window
    }

    private func showWindow() {
        os_log("showWindow() called", log: .default, type: .info)

        // Find any existing SwiftUI window (not status bar windows)
        let foundWindow = NSApp.windows.first { window in
            return window.styleMask.contains(.titled) &&
                   !window.className.contains("NSStatusBar")
        }

        if let window = foundWindow {
            os_log("Found existing window, showing it", log: .default, type: .info)
            mainWindow = window
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            // No window exists - need to create one
            os_log("No window found, creating new window...", log: .default, type: .info)
            createAndShowWindow()
        }
    }

    private func createAndShowWindow() {
        // Create a new SwiftUI window programmatically
        let contentView = ContentView(settings: settingsManager)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.title = "BuenMouse"
        window.center()
        window.setFrameAutosaveName("BuenMouseMainWindow")

        // Keep reference
        mainWindow = window

        // Show it
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        os_log("New window created and shown", log: .default, type: .info)
    }

    private func hideWindow() {
        if let window = mainWindow {
            window.orderOut(nil)
            os_log("Window hidden", log: .default, type: .info)
        } else {
            // Try to find and hide any app window
            for window in NSApp.windows {
                if window.contentView != nil && !window.title.isEmpty {
                    window.orderOut(nil)
                }
            }
        }
    }

    // MARK: - Public Methods for Settings
    func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)

        if settingsManager.isMonitoringActive {
            // Active: filled mouse icon
            if let image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "BuenMouse - Active") {
                button.image = image.withSymbolConfiguration(config)
                button.contentTintColor = nil // Default color
            }
        } else {
            // Inactive: mouse with slash (disabled look)
            if let image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "BuenMouse - Inactive") {
                button.image = image.withSymbolConfiguration(config)
                button.contentTintColor = .gray
            }
        }
    }

    // Called when monitoring changes from Settings UI
    func onMonitoringChanged() {
        updateStatusBarIcon()

        // Update menu item state
        if let menu = statusItem?.menu,
           let monitoringItem = menu.item(withTitle: "Gesture Monitoring") {
            monitoringItem.state = settingsManager.isMonitoringActive ? .on : .off
        }
    }
}
