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
    private var permissionFlow: PermissionFlow?
    private var wakeObserver: NSObjectProtocol?
    private var accessibilityObserver: NSObjectProtocol?

    /// Posted by macOS whenever the Accessibility trust database changes.
    private static let accessibilityChanged = Notification.Name("com.apple.accessibility.api")

    /// The unit tests are hosted by the app; XCTest must not get the status
    /// item, the onboarding window, the event tap, or the updater.
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard !Self.isRunningTests else { return }

        setupComponents()
        setupMenuBar()
        permissionFlow = makePermissionFlow()
        configureLaunchAtLoginDefault()
        UpdateManager.shared.start()

        settingsManager.onMonitoringChanged = { [weak self] in
            self?.applyMonitoringState()
        }

        applyMonitoringState()
        permissionFlow?.presentIfNeeded()

        // After sleep the session tap can come back disabled; re-assert it.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.eventMonitor?.reassertTap()
            }
        }

        accessibilityObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.accessibilityChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAccessibilityChange()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        applyMonitoringState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stopMonitoring()
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = accessibilityObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
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
        let gesture = GestureHandler(settingsManager: settingsManager)
        scrollHandler = scroll
        gestureHandler = gesture
        eventMonitor = EventMonitor(gestureHandler: gesture, scrollHandler: scroll)
    }

    private func setupMenuBar() {
        let controller = MenuBarStatusController(settings: settingsManager)
        controller.onOpenPermissions = { [weak self] in
            self?.permissionFlow?.present()
        }
        controller.isMonitoringReady = { [weak self] in self?.eventMonitor?.isReady == true }
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
            eventMonitor?.reassertTap()
        } else {
            eventMonitor?.stopMonitoring()
        }
        menuBarController?.refreshStatusIcon()
    }

    /// The notification lands before `AXIsProcessTrusted()` reports the new
    /// value, so reconcile again while the change propagates.
    private func handleAccessibilityChange() {
        applyMonitoringState()
        for delay in [0.5, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.applyMonitoringState()
            }
        }
    }

    // MARK: - Permission Onboarding

    private func makePermissionFlow() -> PermissionFlow {
        let flow = PermissionFlow(
            configuration: PermissionFlowConfiguration(
                appName: "BuenMouse",
                icon: NSApp.applicationIconImage,
                accent: Theme.accent,
                items: [
                    PermissionFlowItem(
                        .accessibility,
                        reason: permissionText("permissions.reason.accessibility")
                    ),
                    PermissionFlowItem(
                        .automation,
                        reason: permissionText("permissions.reason.automation")
                    ),
                ],
                language: { LocalizationManager.shared.language == "es" ? .spanish : .english },
                legacyCompletionKeys: ["didConfigureLaunchAtLogin"],
                automationTarget: "com.apple.systemevents",
                isReady: { [weak self] in self?.monitoringReady() ?? false },
                pendingRelaunch: { [weak self] in
                    guard let self else { return false }
                    return AccessibilityPermission.isGranted && !self.monitoringReady()
                },
                menuBarAnchor: { [weak self] in self?.menuBarController?.statusButtonFrame }
            )
        )
        flow.model.onGranted = { [weak self] _ in self?.applyMonitoringState() }
        return flow
    }

    private func permissionText(_ key: String) -> PermissionFlowText {
        func text(_ language: String) -> String {
            let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
            return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        }
        return PermissionFlowText(text("en"), text("es"))
    }

    private func monitoringReady() -> Bool {
        applyMonitoringState()
        return !settingsManager.isMonitoringActive || eventMonitor?.isReady == true
    }
}
