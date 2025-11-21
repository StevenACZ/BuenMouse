import Cocoa
import SwiftUI
import os.log

enum WindowState {
    case hidden
    case visible
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: - Components
    let settingsManager = SettingsManager()
    private var eventMonitor: EventMonitor?
    private var gestureHandler: GestureHandler?
    private var scrollHandler: ScrollHandler?

    var window: NSWindow? {
        didSet {
            os_log("Window reference set: %{public}@", log: .default, type: .info, window != nil ? "YES" : "NO")
            if window != nil {
                windowState = .visible
            }
        }
    }
    private var statusItem: NSStatusItem?
    private var windowState: WindowState = .visible

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

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            updateStatusBarIcon()
            button.action = #selector(statusItemClicked)
            button.target = self

            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Show Settings", action: #selector(showSettingsClicked), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())

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
        hideWindow()
    }

    private func showWindow() {
        // Try to recover window if nil
        if window == nil {
            recoverWindowReference()
        }

        guard let window = window else {
            os_log("ERROR: Cannot show window - reference is nil", log: .default, type: .error)
            return
        }

        os_log("Showing window...", log: .default, type: .info)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.level = .normal
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        windowState = .visible

        os_log("Window shown", log: .default, type: .info)
    }

    private func hideWindow() {
        guard let window = window else {
            os_log("Cannot hide window: reference is nil", log: .default, type: .error)
            return
        }

        os_log("Hiding window...", log: .default, type: .info)
        window.orderOut(nil)
        windowState = .hidden
    }

    private func recoverWindowReference() {
        os_log("Recovering window reference...", log: .default, type: .info)
        let allWindows = NSApp.windows

        for win in allWindows {
            if let contentView = win.contentView,
               String(describing: type(of: contentView)).contains("NSHostingView") {
                window = win
                os_log("Window recovered", log: .default, type: .info)
                return
            }
        }

        if window == nil && !allWindows.isEmpty {
            window = allWindows.first
            os_log("Using first window as fallback", log: .default, type: .info)
        }
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

        // Animate icon change
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            button.animator().alphaValue = 0.5
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                button.animator().alphaValue = 1.0
            })
        })

        if let menu = statusItem?.menu,
           let toggleItem = menu.item(withTag: 999) {
            toggleItem.title = settingsManager.isMonitoringActive ? "Disable Monitoring" : "Enable Monitoring"
        }
    }

    @objc private func toggleMonitoring() {
        settingsManager.isMonitoringActive.toggle()
    }

    @objc private func showSettingsClicked() {
        showWindow()
    }

    @objc private func statusItemClicked() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            return
        }

        if windowState == .visible, let win = window, win.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
}
