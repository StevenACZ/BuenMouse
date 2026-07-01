import AppKit
import SwiftUI

/// Central design tokens — the single place that defines BuenMouse's look.
enum Theme {
    /// Brand accent, matching the cyan app icon.
    static let accent = Color(nsColor: .systemCyan)
    static let nsAccent = NSColor.systemCyan

    enum Layout {
        static let panelWidth: CGFloat = 320
        static let cornerRadius: CGFloat = 12
    }

    enum Anim {
        static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let easeOut = Animation.easeOut(duration: 0.2)
        static let slide = Animation.easeInOut(duration: 0.35)
    }
}
