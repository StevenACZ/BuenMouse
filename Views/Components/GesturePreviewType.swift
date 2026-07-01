import SwiftUI

/// The four gestures BuenMouse offers, with the copy and accents shared by
/// the menu bar panel grid and the settings showcase.
enum GesturePreviewType: CaseIterable, Hashable {
    case missionControl
    case scrollZoom
    case invertScroll
    case spaceNavigation

    var title: String {
        switch self {
        case .missionControl: return "Middle Click → Mission Control"
        case .spaceNavigation: return "Middle Drag → Switch Spaces"
        case .scrollZoom: return "⌃ + Scroll → Zoom In / Out"
        case .invertScroll: return "Invert Scroll → Natural Direction"
        }
    }

    var subtitle: String {
        switch self {
        case .missionControl: return "Press the scroll wheel to open Mission Control"
        case .spaceNavigation: return "Hold the scroll wheel and drag horizontally"
        case .scrollZoom: return "Hold Control and use the scroll wheel"
        case .invertScroll: return "Reverse the mouse wheel scroll direction"
        }
    }

    /// Compact name for the panel grid tiles.
    var shortTitle: String {
        switch self {
        case .missionControl: return "Mission Control"
        case .spaceNavigation: return "Switch Spaces"
        case .scrollZoom: return "Scroll Zoom"
        case .invertScroll: return "Invert Scroll"
        }
    }

    var symbol: String {
        switch self {
        case .missionControl: return "rectangle.3.group"
        case .spaceNavigation: return "rectangle.split.3x1"
        case .scrollZoom: return "plus.magnifyingglass"
        case .invertScroll: return "arrow.up.arrow.down"
        }
    }

    var accent: Color {
        switch self {
        case .missionControl: return .purple
        case .spaceNavigation: return .blue
        case .scrollZoom: return .green
        case .invertScroll: return .green
        }
    }
}
