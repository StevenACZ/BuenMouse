import Cocoa
import SwiftUI
import os.log

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: - Components
    let settingsManager = SettingsManager()
    private var eventMonitor: EventMonitor?
    private var gestureHandler: GestureHandler?
    private var scrollHandler: ScrollHandler?
    private var statusItem: NSStatusItem?

    override init() {
        super.init()
        settingsManager.appDelegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log("Application launching...", log: .default, type: .info)

        setupStatusBar()
        setupComponents()
        eventMonitor?.requestPermissions()

        if settingsManager.isMonitoringActive {
            eventMonitor?.startMonitoring()
        }

        settingsManager.setupAppearanceObserver()
        settingsManager.updateAppearance()
        updateStatusBarIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window is closed - keep running in background with menu bar icon
        return false
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            updateStatusBarIcon()

            let menu = NSMenu()

            let toggleItem = NSMenuItem(title: settingsManager.isMonitoringActive ? "Disable Monitoring" : "Enable Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "")
            toggleItem.target = self
            toggleItem.tag = 999
            menu.addItem(toggleItem)

            menu.addItem(NSMenuItem.separator())
            let quitItem = NSMenuItem(title: "Quit BuenMouse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            menu.addItem(quitItem)

            statusItem?.menu = menu
        }
    }

    private func setupComponents() {
        scrollHandler = ScrollHandler(settingsManager: settingsManager)
        gestureHandler = GestureHandler(settingsManager: settingsManager, scrollHandler: scrollHandler!)
        eventMonitor = EventMonitor(gestureHandler: gestureHandler!, scrollHandler: scrollHandler!)
    }

    func moveToMenuBar() {
        // Just close the window - app stays running with Dock and menu bar icon
        NSApp.keyWindow?.close()
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

        let iconName = settingsManager.isMonitoringActive ? "cursorarrow" : "cursorarrow.slash"
        let tooltip = settingsManager.isMonitoringActive ? "BuenMouse: Active" : "BuenMouse: Inactive"

        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "BuenMouse")
        button.toolTip = tooltip

        if let menu = statusItem?.menu,
           let toggleItem = menu.item(withTag: 999) {
            toggleItem.title = settingsManager.isMonitoringActive ? "Disable Monitoring" : "Enable Monitoring"
        }
    }

    @objc private func toggleMonitoring() {
        settingsManager.isMonitoringActive.toggle()
    }
}
