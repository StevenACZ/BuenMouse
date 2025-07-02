import Foundation
import SwiftUI

final class SettingsManager: ObservableObject, SettingsProtocol {
    // MARK: - Persisted Settings
    @Published var isMonitoringActive: Bool = UserDefaults.standard.bool(forKey: "isMonitoringActive") {
        didSet { UserDefaults.standard.set(isMonitoringActive, forKey: "isMonitoringActive") }
    }

    @Published var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: "launchAtLogin") {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
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
    
    func moveToMenuBar() {}
} 