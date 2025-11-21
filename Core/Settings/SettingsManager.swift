import Foundation
import SwiftUI
import os.log

final class SettingsManager: ObservableObject, SettingsProtocol {
    // MARK: - Referencia al AppDelegate
    weak var appDelegate: AppDelegate?

    // MARK: - Persisted Settings
    @Published var isMonitoringActive: Bool = {
        let value = UserDefaults.standard.object(forKey: "isMonitoringActive")
        return value as? Bool ?? true // Default to true for first launch
    }() {
        didSet {
            UserDefaults.standard.set(isMonitoringActive, forKey: "isMonitoringActive")
            appDelegate?.updateMonitoring(isActive: isMonitoringActive)
        }
    }

    @Published var invertDragDirection: Bool = UserDefaults.standard.bool(forKey: "invertDragDirection") {
        didSet { UserDefaults.standard.set(invertDragDirection, forKey: "invertDragDirection") }
    }

    @Published var dragThreshold: Double = {
        let value = UserDefaults.standard.double(forKey: "dragThreshold")
        return value == 0 ? 40.0 : value
    }() {
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
    }() {
        didSet { UserDefaults.standard.set(enableMissionControl, forKey: "enableMissionControl") }
    }

    @Published var enableSpaceNavigation: Bool = {
        let value = UserDefaults.standard.object(forKey: "enableSpaceNavigation")
        return value as? Bool ?? true
    }() {
        didSet { UserDefaults.standard.set(enableSpaceNavigation, forKey: "enableSpaceNavigation") }
    }

    @Published var isDarkMode: Bool = UserDefaults.standard.bool(forKey: "isDarkMode") {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
            updateAppearance()
        }
    }

    @Published var followSystemAppearance: Bool = {
        let value = UserDefaults.standard.object(forKey: "followSystemAppearance")
        return value as? Bool ?? true // Default to true
    }() {
        didSet {
            UserDefaults.standard.set(followSystemAppearance, forKey: "followSystemAppearance")
            updateAppearance()
        }
    }

    func moveToMenuBar() {
        DispatchQueue.main.async {
            self.appDelegate?.moveToMenuBar()
            os_log("Moving to menu bar requested", log: .default, type: .info)
        }
    }

    func updateAppearance() {
        let updateBlock = {
            if self.followSystemAppearance {
                NSApp.appearance = nil
                os_log("Appearance set to follow system", log: .default, type: .info)
            } else {
                let appearance = NSAppearance(named: self.isDarkMode ? .darkAqua : .aqua)
                NSApp.appearance = appearance
                os_log("Appearance set to: %{public}@", log: .default, type: .info, self.isDarkMode ? "dark" : "light")
            }
        }

        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async(execute: updateBlock)
        }
    }

    func setupAppearanceObserver() {
        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }

            if self.followSystemAppearance {
                os_log("System appearance changed, updating UI", log: .default, type: .info)
                self.objectWillChange.send()
                self.updateAppearance()
            }
        }

        os_log("Appearance observer set up", log: .default, type: .info)
    }

    func resetToDefaults() {
        os_log("Resetting all settings to defaults", log: .default, type: .info)

        isMonitoringActive = true
        invertDragDirection = false
        dragThreshold = 40.0
        invertScroll = false
        enableScrollZoom = false
        enableMissionControl = true
        enableSpaceNavigation = true
        isDarkMode = false
        followSystemAppearance = true

        os_log("All settings reset to defaults", log: .default, type: .info)
    }
}
