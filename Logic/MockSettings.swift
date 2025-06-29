import Foundation

final class MockSettings: SettingsProtocol {
    @Published var isMonitoringActive = true
    @Published var launchAtLogin = true
    @Published var startInMenubar = false
    @Published var invertDragDirection = true
    @Published var invertScroll = false
    @Published var dragThreshold: Double = 80
    @Published var enableScrollZoom = false

    func moveToMenuBar() {}
}
