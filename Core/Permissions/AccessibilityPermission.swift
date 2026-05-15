import AppKit
import ApplicationServices

/// Single source of truth for the only permission BuenMouse needs.
enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the native "do you want to grant access" prompt.
    /// Returns the post-prompt status (synchronous, but harmless to ignore).
    @discardableResult
    static func primeSystemPrompt() -> Bool {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true
        ]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings directly to Privacy → Accessibility.
    /// Tries the modern anchor first, falls back to the legacy one.
    static func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    /// Bundle URL — used as the drag item so the user can drop the app
    /// straight into the Accessibility list in System Settings.
    static var appBundleURL: URL {
        Bundle.main.bundleURL
    }
}
