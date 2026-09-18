import AppKit
import QuartzCore

@MainActor
final class PermissionAssistant: NSObject {
    static let shared = PermissionAssistant()

    private var overlayController: PermissionOverlayWindowController?
    private let locator = PermissionSettingsWindowLocator()
    private var discoveryTimer: Timer?
    private var displayLink: CADisplayLink?
    private var isActive = false
    private var pendingSourceFrameInScreen: CGRect?
    private var didPresentCurrentOverlay = false

    private override init() {
        super.init()
    }

    func present(sourceFrameInScreen: CGRect? = nil) {
        dismiss()

        isActive = true
        pendingSourceFrameInScreen = sourceFrameInScreen
        didPresentCurrentOverlay = false
        overlayController = PermissionOverlayWindowController(
            hostApp: PermissionHostApp.current(),
            accentColor: .systemBlue
        ) { [weak self] in
            self?.dismiss()
        }

        AccessibilityPermission.openSystemSettings()
        startTracking()
    }

    func dismiss() {
        discoveryTimer?.invalidate()
        discoveryTimer = nil
        stopTracking()
        locator.reset()
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        overlayController?.close()
        overlayController = nil
        isActive = false
        pendingSourceFrameInScreen = nil
        didPresentCurrentOverlay = false
    }

    private func startTracking() {
        discoveryTimer = Timer.scheduledTimer(
            timeInterval: 0.5, target: self, selector: #selector(discover),
            userInfo: nil, repeats: true
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(discover),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        discover()
    }

    @objc
    private func discover() {
        guard isActive else { return }
        if AccessibilityPermission.isGranted {
            dismiss()
            return
        }
        guard let snapshot = locator.discover() else {
            hide()
            return
        }
        position(snapshot)
        guard let window = overlayController?.window, window.isVisible else {
            stopTracking()
            return
        }
        guard displayLink == nil else { return }
        let link = window.displayLink(target: self, selector: #selector(track))
        link.add(to: .main, forMode: .common)
        displayLink = link
        updateRefreshRate()
    }

    @objc
    private func track() {
        guard overlayController?.window?.isVisible == true, let snapshot = locator.trackedWindow() else {
            hide()
            return
        }
        position(snapshot)
        if overlayController?.window?.isVisible != true { stopTracking() }
        updateRefreshRate()
    }

    private func position(_ snapshot: PermissionSettingsWindowSnapshot) {
        if didPresentCurrentOverlay {
            overlayController?.updatePosition(with: snapshot.frame, visibleFrame: snapshot.visibleFrame)
        } else {
            overlayController?.present(
                from: pendingSourceFrameInScreen,
                settingsFrame: snapshot.frame, visibleFrame: snapshot.visibleFrame
            )
            didPresentCurrentOverlay = overlayController?.window?.isVisible == true
        }
    }

    private func hide() {
        stopTracking()
        overlayController?.hide()
    }

    private func stopTracking() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateRefreshRate() {
        guard let displayLink else { return }
        let rate = Float(min(120, max(30, overlayController?.window?.screen?.maximumFramesPerSecond ?? 60)))
        if displayLink.preferredFrameRateRange.maximum != rate {
            displayLink.preferredFrameRateRange = CAFrameRateRange(
                minimum: min(60, rate), maximum: rate, preferred: rate
            )
        }
    }
}
