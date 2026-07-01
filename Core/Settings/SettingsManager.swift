import Foundation
import SwiftUI
import os.log

final class SettingsManager: ObservableObject, SettingsProtocol {
    /// Fired when the master switch flips so the app can start/stop the tap.
    var onMonitoringChanged: (() -> Void)?

    // MARK: - Persisted Settings

    @Published var isMonitoringActive: Bool = {
        let value = UserDefaults.standard.object(forKey: "isMonitoringActive")
        return value as? Bool ?? true  // Default to true for first launch
    }()
    {
        didSet {
            UserDefaults.standard.set(isMonitoringActive, forKey: "isMonitoringActive")
            onMonitoringChanged?()
        }
    }

    @Published var invertDragDirection: Bool = UserDefaults.standard.bool(forKey: "invertDragDirection") {
        didSet { UserDefaults.standard.set(invertDragDirection, forKey: "invertDragDirection") }
    }

    @Published var dragThreshold: Double = {
        // Use object(forKey:) so we can tell "never set" (nil) apart from a legit stored 0.
        if let stored = UserDefaults.standard.object(forKey: "dragThreshold") as? Double {
            return min(250, max(50, stored))
        }
        return 100.0
    }()
    {
        didSet { UserDefaults.standard.set(dragThreshold, forKey: "dragThreshold") }
    }

    @Published var invertScroll: Bool = UserDefaults.standard.bool(forKey: "invertScroll") {
        didSet { UserDefaults.standard.set(invertScroll, forKey: "invertScroll") }
    }

    @Published var enableScrollZoom: Bool = UserDefaults.standard.bool(forKey: "enableScrollZoom") {
        didSet { UserDefaults.standard.set(enableScrollZoom, forKey: "enableScrollZoom") }
    }

    @Published var enableMissionControl: Bool = {
        let value = UserDefaults.standard.object(forKey: "enableMissionControl")
        return value as? Bool ?? true
    }()
    {
        didSet { UserDefaults.standard.set(enableMissionControl, forKey: "enableMissionControl") }
    }

    @Published var enableSpaceNavigation: Bool = {
        let value = UserDefaults.standard.object(forKey: "enableSpaceNavigation")
        return value as? Bool ?? true
    }()
    {
        didSet { UserDefaults.standard.set(enableSpaceNavigation, forKey: "enableSpaceNavigation") }
    }

    /// Seeded from the real SMAppService state so the toggle never lies.
    @Published var launchAtLogin: Bool = ServiceManager.isEnabled {
        didSet {
            guard oldValue != launchAtLogin else { return }
            ServiceManager.setEnabled(launchAtLogin)
        }
    }

    func resetToDefaults() {
        os_log("Resetting all settings to defaults", log: .default, type: .info)

        isMonitoringActive = true
        invertDragDirection = false
        dragThreshold = 100.0
        invertScroll = false
        enableScrollZoom = false
        enableMissionControl = true
        enableSpaceNavigation = true
    }
}
