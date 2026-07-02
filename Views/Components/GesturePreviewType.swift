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
        case .missionControl: return "gesture.mission_control.title".localized
        case .spaceNavigation: return "gesture.space_navigation.title".localized
        case .scrollZoom: return "gesture.scroll_zoom.title".localized
        case .invertScroll: return "gesture.invert_scroll.title".localized
        }
    }

    var subtitle: String {
        switch self {
        case .missionControl: return "gesture.mission_control.subtitle".localized
        case .spaceNavigation: return "gesture.space_navigation.subtitle".localized
        case .scrollZoom: return "gesture.scroll_zoom.subtitle".localized
        case .invertScroll: return "gesture.invert_scroll.subtitle".localized
        }
    }

    /// Compact name for the panel grid tiles.
    var shortTitle: String {
        switch self {
        case .missionControl: return "gesture.mission_control.short".localized
        case .spaceNavigation: return "gesture.space_navigation.short".localized
        case .scrollZoom: return "gesture.scroll_zoom.short".localized
        case .invertScroll: return "gesture.invert_scroll.short".localized
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
