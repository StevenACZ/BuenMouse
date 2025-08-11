import Foundation
import SwiftUI

protocol SettingsProtocol: ObservableObject {
    var isMonitoringActive: Bool { get set }
    var launchAtLogin: Bool { get set }
    var launchAtLoginError: String? { get set }
    var startInMenubar: Bool { get set }
    var invertDragDirection: Bool { get set }
    var dragThreshold: Double { get set }
    var invertScroll: Bool { get set }
    var enableScrollZoom: Bool { get set }
    var isDarkMode: Bool { get set }
    var followSystemAppearance: Bool { get set }
    
    func moveToMenuBar()
    func updateLaunchAtLogin(_ enabled: Bool)
} 