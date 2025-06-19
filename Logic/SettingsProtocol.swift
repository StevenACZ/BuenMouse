import Foundation
import SwiftUI

protocol SettingsProtocol: ObservableObject {
    var isMonitoringActive: Bool { get set }
    var launchAtLogin: Bool { get set }
    var startInMenubar: Bool { get set }
    var invertDragDirection: Bool { get set }
    var dragThreshold: Double { get set }
    var invertScroll: Bool { get set }
    func moveToMenuBar()
}
