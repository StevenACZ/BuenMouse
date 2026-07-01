import Cocoa
import SwiftUI
import os.log

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsManager = SettingsManager()

    private var scrollHandler: ScrollHandler?
    private var gestureHandler: GestureHandler?
    private var eventMonitor: EventMonitor?
    private var menuBarController: MenuBarStatusController?
    private var permissionWindowController: PermissionWindowController?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupComponents()
        setupMenuBar()
        configureLaunchAtLoginDefault()

        settingsManager.onMonitoringChanged = { [weak self] in
            self?.applyMonitoringState()
        }

        if AccessibilityPermission.isGranted {
            applyMonitoringState()
        } else {
            showPermissionOnboarding()
        }

        // After sleep the session tap can come back disabled; re-assert it.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.eventMonitor?.reassertTap()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stopMonitoring()
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Relaunching the app (Finder, Spotlight, Launchpad) must not flash any
    /// window — the status item is the only entry point.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }

    // MARK: - Setup

    private func setupComponents() {
        let scroll = ScrollHandler(settingsManager: settingsManager)
        let gesture = GestureHandler(settingsManager: settingsManager, scrollHandler: scroll)
        scrollHandler = scroll
        gestureHandler = gesture
        eventMonitor = EventMonitor(gestureHandler: gesture, scrollHandler: scroll)
    }

    private func setupMenuBar() {
        let controller = MenuBarStatusController(settings: settingsManager)
        controller.onOpenPermissions = { [weak self] in
            self?.showPermissionOnboarding()
        }
        menuBarController = controller
        controller.start()
    }

    /// First launch only: opt the app into launch-at-login so an always-on
    /// utility is on by default, while later user choices are respected.
    private func configureLaunchAtLoginDefault() {
        let key = "didConfigureLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        settingsManager.launchAtLogin = true
    }

    // MARK: - Monitoring

    private func applyMonitoringState() {
        if settingsManager.isMonitoringActive && AccessibilityPermission.isGranted {
            eventMonitor?.startMonitoring()
        } else {
            eventMonitor?.stopMonitoring()
        }
        menuBarController?.refreshStatusIcon()
    }

    // MARK: - Permission Onboarding

    private func showPermissionOnboarding() {
        if permissionWindowController == nil {
            let controller = PermissionWindowController()
            controller.onPermissionGranted = { [weak self] in
                self?.handlePermissionGranted()
            }
            permissionWindowController = controller
        }
        permissionWindowController?.show()
    }

    private func handlePermissionGranted() {
        os_log("Accessibility permission granted — starting monitoring", log: .default, type: .info)
        applyMonitoringState()

        // Give the user 1 s to see the "You're all set!" success state, then close.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.permissionWindowController?.close()
            self?.permissionWindowController = nil
        }
    }
}
