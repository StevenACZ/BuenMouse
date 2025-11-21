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
        showWindow()
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

        if let button = statusItem?.button {
            // Use SF Symbol for mouse
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            if let mouseImage = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "BuenMouse") {
                let configuredImage = mouseImage.withSymbolConfiguration(config)
                button.image = configuredImage
            }
            button.action = #selector(statusBarClicked)
            button.target = self
        }
    }

    @objc private func statusBarClicked() {
        os_log("=== STATUS BAR CLICKED ===", log: .default, type: .info)
        os_log("mainWindow reference: %{public}@", log: .default, type: .info, mainWindow == nil ? "NIL" : "EXISTS")
        os_log("NSApp.windows.count: %d", log: .default, type: .info, NSApp.windows.count)

        // Log all windows for debugging
        for (index, window) in NSApp.windows.enumerated() {
            os_log("Window[%d]: class=%{public}@, visible=%{public}@, titled=%{public}@",
                   log: .default, type: .info,
                   index,
                   window.className,
                   window.isVisible ? "YES" : "NO",
                   window.styleMask.contains(.titled) ? "YES" : "NO")
        }

        if let window = mainWindow, window.isVisible {
            os_log("Action: HIDE (window exists and visible)", log: .default, type: .info)
            hideWindow()
        } else {
            os_log("Action: SHOW (window nil or hidden)", log: .default, type: .info)
            showWindow()
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
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

        let symbolName = settingsManager.isMonitoringActive ? "computermouse.fill" : "computermouse"
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "BuenMouse") {
            button.image = image.withSymbolConfiguration(config)
        }
    }
}
