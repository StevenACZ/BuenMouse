import Foundation
import SwiftUI

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

    @Published var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: "launchAtLogin") {
        didSet { 
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            configureLaunchAtLogin()
        }
    }

    @Published var startInMenubar: Bool = UserDefaults.standard.bool(forKey: "startInMenubar") {
        didSet { UserDefaults.standard.set(startInMenubar, forKey: "startInMenubar") }
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
        appDelegate?.moveToMenuBar()
    }
    
    private func configureLaunchAtLogin() {
        if launchAtLogin {
            ServiceManager.register()
        } else {
            ServiceManager.unregister()
        }
    }
    
    func updateAppearance() {
        DispatchQueue.main.async {
            if self.followSystemAppearance {
                NSApp.appearance = nil // Follow system
            } else {
                NSApp.appearance = NSAppearance(named: self.isDarkMode ? .darkAqua : .aqua)
            }
        }
    }
    
    func setupAppearanceObserver() {
        // Observer for system appearance changes
        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.followSystemAppearance == true {
                self?.objectWillChange.send()
            }
        }
    }
} 
