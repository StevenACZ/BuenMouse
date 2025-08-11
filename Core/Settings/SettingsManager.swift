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
            updateLaunchAtLogin(launchAtLogin)
        }
    }
    
    @Published var launchAtLoginError: String? = nil

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
    
    func updateLaunchAtLogin(_ enabled: Bool) {
        let result = enabled ? ServiceManager.register() : ServiceManager.unregister()
        
        switch result {
        case .success:
            launchAtLoginError = nil
        case .failure(let error):
            handleServiceError(error)
        }
    }
    
    func verifyLaunchAtLoginStatus() {
        let isInSync = ServiceManager.syncWithUserDefaults()
        
        if !isInSync {
            print("⚠️ Estado de launch at login desincronizado, intentando corregir...")
            updateLaunchAtLogin(launchAtLogin)
        }
    }
    
    private func handleServiceError(_ error: ServiceError) {
        DispatchQueue.main.async {
            self.launchAtLoginError = error.localizedDescription
            print("❌ Error en launch at login: \(error.localizedDescription)")
        }
    }
    
    private func configureLaunchAtLogin() {
        updateLaunchAtLogin(launchAtLogin)
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
