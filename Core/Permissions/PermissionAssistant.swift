import AppKit

/// Coordinates the floating guidance overlay that follows System Settings
/// while the user is granting Accessibility access.
@MainActor
final class PermissionAssistant: NSObject {
    static let shared = PermissionAssistant()

    private var overlayController: PermissionOverlayWindowController?
    private var trackingTimer: Timer?
    private var pendingSourceFrameInScreen: CGRect?
    private var didPresentCurrentOverlay = false
    private var isActive = false

    private override init() {
        super.init()
    }

    /// Opens System Settings → Privacy → Accessibility and starts tracking
    /// its window so the overlay stays glued to it.
    func present(sourceFrameInScreen: CGRect? = nil) {
        dismiss()

        pendingSourceFrameInScreen = sourceFrameInScreen
        didPresentCurrentOverlay = false
        isActive = true

        let accent = Theme.nsAccent
        overlayController = PermissionOverlayWindowController(
            hostApp: PermissionHostApp.current(),
            accentColor: accent
        ) { [weak self] in
            self?.dismiss()
        }

        AccessibilityPermission.openSystemSettings()
        startTracking()
    }

    func dismiss() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        overlayController?.close()
        overlayController = nil
        pendingSourceFrameInScreen = nil
        didPresentCurrentOverlay = false
        isActive = false
    }

    private func startTracking() {
        trackingTimer?.invalidate()
        trackingTimer = Timer.scheduledTimer(
            timeInterval: 0.15,
            target: self,
            selector: #selector(handleTrackingTimer),
            userInfo: nil,
            repeats: true
        )

        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleApplicationActivation),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        refreshPosition()
    }

    @objc
    private func handleTrackingTimer() {
        refreshPosition()
    }

    @objc
    private func handleApplicationActivation(_ notification: Notification) {
        refreshPosition()
    }

    private func refreshPosition() {
        guard isActive else { return }

        if AccessibilityPermission.isGranted {
            dismiss()
            return
        }

        guard let snapshot = PermissionSettingsWindowLocator.frontmostWindow() else {
            overlayController?.hide()
            return
        }

        if didPresentCurrentOverlay {
            overlayController?.updatePosition(with: snapshot.frame, visibleFrame: snapshot.visibleFrame)
            return
        }

        overlayController?.present(
            from: pendingSourceFrameInScreen,
            settingsFrame: snapshot.frame,
            visibleFrame: snapshot.visibleFrame
        )
        didPresentCurrentOverlay = true
    }
}
