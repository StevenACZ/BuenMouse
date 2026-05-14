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
        rebuildStatusBarMenu()
    }

    /// Rebuilds the entire menu so checkmarks stay in sync with settings.
    /// Called on every settings change that affects the menu.
    private func rebuildStatusBarMenu() {
        let menu = NSMenu()

        let showSettingsItem = NSMenuItem(title: "Show Settings", action: #selector(showSettingsClicked), keyEquivalent: ",")
        showSettingsItem.target = self
        menu.addItem(showSettingsItem)

        menu.addItem(NSMenuItem.separator())

        let monitoringItem = NSMenuItem(title: "Gesture Monitoring", action: #selector(toggleMonitoringClicked), keyEquivalent: "")
        monitoringItem.target = self
        monitoringItem.state = settingsManager.isMonitoringActive ? .on : .off
        menu.addItem(monitoringItem)

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLoginClicked), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = settingsManager.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        // Appearance submenu
        let appearanceItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        let appearanceSubmenu = NSMenu(title: "Appearance")

        let systemItem = NSMenuItem(title: "System", action: #selector(selectAppearanceSystem), keyEquivalent: "")
        systemItem.target = self
        systemItem.state = settingsManager.followSystemAppearance ? .on : .off
        appearanceSubmenu.addItem(systemItem)

        let lightItem = NSMenuItem(title: "Light", action: #selector(selectAppearanceLight), keyEquivalent: "")
        lightItem.target = self
        lightItem.state = (!settingsManager.followSystemAppearance && !settingsManager.isDarkMode) ? .on : .off
        appearanceSubmenu.addItem(lightItem)

        let darkItem = NSMenuItem(title: "Dark", action: #selector(selectAppearanceDark), keyEquivalent: "")
        darkItem.target = self
        darkItem.state = (!settingsManager.followSystemAppearance && settingsManager.isDarkMode) ? .on : .off
        appearanceSubmenu.addItem(darkItem)

        appearanceItem.submenu = appearanceSubmenu
        menu.addItem(appearanceItem)

        menu.addItem(NSMenuItem.separator())

        let resetItem = NSMenuItem(title: "Reset to Defaults…", action: #selector(resetClicked), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        let aboutItem = NSMenuItem(title: "About BuenMouse", action: #selector(aboutClicked), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

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
        applyMonitoringChange()
    }

    private func applyMonitoringChange() {
        updateStatusBarIcon()
        rebuildStatusBarMenu()

        if settingsManager.isMonitoringActive {
            eventMonitor?.startMonitoring()
        } else {
            eventMonitor?.stopMonitoring()
        }

        os_log("Monitoring toggled: %{public}@", log: .default, type: .info,
               settingsManager.isMonitoringActive ? "ON" : "OFF")
    }

    @objc private func toggleLaunchAtLoginClicked() {
        settingsManager.launchAtLogin.toggle()
        rebuildStatusBarMenu()
    }

    @objc private func selectAppearanceSystem() {
        settingsManager.followSystemAppearance = true
        rebuildStatusBarMenu()
    }

    @objc private func selectAppearanceLight() {
        settingsManager.followSystemAppearance = false
        settingsManager.isDarkMode = false
        rebuildStatusBarMenu()
    }

    @objc private func selectAppearanceDark() {
        settingsManager.followSystemAppearance = false
        settingsManager.isDarkMode = true
        rebuildStatusBarMenu()
    }

    @objc private func resetClicked() {
        let alert = NSAlert()
        alert.messageText = "Reset all settings to defaults?"
        alert.informativeText = "This restores every BuenMouse preference. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            settingsManager.resetToDefaults()
            rebuildStatusBarMenu()
        }
    }

    @objc private func aboutClicked() {
        let alert = NSAlert()
        alert.messageText = "BuenMouse"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        alert.informativeText = "Version \(version)\nAdvanced mouse gestures for macOS.\nCreated by Steven Coaila Zaa.\nMIT License."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub Repository")
        if alert.runModal() == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/StevenACZ/BuenMouse") {
                NSWorkspace.shared.open(url)
            }
        }
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
        applyMonitoringChange()
    }
}
