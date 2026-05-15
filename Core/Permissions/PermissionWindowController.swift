import AppKit
import SwiftUI

/// Owns the lifetime of the permission onboarding window. Notifies the app
/// delegate when the user grants Accessibility so monitoring can start.
final class PermissionWindowController: NSWindowController, NSWindowDelegate {
    /// Fires once the permission flips from denied → granted. The window
    /// closes shortly after; the delegate decides what to do next.
    var onPermissionGranted: (() -> Void)?

    private var hostingController: NSHostingController<PermissionRequirementsView>?
    private var pollTimer: Timer?
    private var hasNotified: Bool = false

    init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        if let existing = window {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let size = PermissionRequirementsView.windowSize
        let view = PermissionRequirementsView(
            onActivate: { [weak self] in self?.handleActivate() },
            onClose: { [weak self] in self?.close() }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = CGRect(origin: .zero, size: size)
        hostingController = hosting

        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "BuenMouse — Setup"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isReleasedWhenClosed = false
        win.isMovableByWindowBackground = false
        win.delegate = self
        win.standardWindowButton(.miniaturizeButton)?.isHidden = true
        win.standardWindowButton(.zoomButton)?.isHidden = true
        win.contentViewController = hosting
        win.center()
        self.window = win

        hasNotified = AccessibilityPermission.isGranted
        startPolling()

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
    }

    override func close() {
        PermissionAssistant.shared.dismiss()
        window?.close()
    }

    private func handleActivate() {
        guard !AccessibilityPermission.isGranted else { return }
        let sourceFrame = sourceFrameForOverlay()
        PermissionAssistant.shared.present(sourceFrameInScreen: sourceFrame)
    }

    /// Anchors the overlay's "fly from" rect to the requirements window so
    /// the helper feels like it pops out of the BuenMouse setup card.
    private func sourceFrameForOverlay() -> CGRect? {
        guard let frame = window?.frame else { return nil }
        return CGRect(
            x: frame.midX - 60,
            y: frame.minY + frame.height * 0.5 - 20,
            width: 120,
            height: 40
        )
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForTransition()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkForTransition() {
        let granted = AccessibilityPermission.isGranted
        guard granted, !hasNotified else { return }
        hasNotified = true
        PermissionAssistant.shared.dismiss()
        onPermissionGranted?()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        stopPolling()
        PermissionAssistant.shared.dismiss()
        hostingController = nil
        window = nil
    }
}
