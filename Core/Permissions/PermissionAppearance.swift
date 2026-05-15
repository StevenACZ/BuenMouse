import AppKit

/// Shared appearance helpers for the AppKit permission overlay surfaces.
/// Mirrors the approach used in SapoWhisper so dark / light switching stays
/// pixel-perfect when the overlay floats over System Settings.
extension NSView {
    var permissionUsesDarkAppearance: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    func permissionCGColor(_ color: NSColor, alpha: CGFloat = 1) -> CGColor {
        var cgColor = color.withAlphaComponent(alpha).cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            cgColor = color.withAlphaComponent(alpha).cgColor
        }
        return cgColor
    }
}
