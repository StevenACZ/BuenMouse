import AppKit
import SwiftUI

final class PermissionWindowController: NSWindowController, NSWindowDelegate {
    var readiness: () -> PermissionReadiness = { .needsPermission }
    private let state = PermissionSetupState()

    private var hostingView: NSHostingView<PermissionRequirementsView>?
    private var pollTimer: Timer?
    private var measuredSize: NSSize?
    private var measuredReadiness: PermissionReadiness?
    private var measuredLanguage: String?

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

        state.readiness = readiness()
        guard let size = measureContentSize() else { return }
        measuredSize = size
        measuredReadiness = state.readiness
        measuredLanguage = LocalizationManager.shared.language
        let hosting = NSHostingView(rootView: makeContent())
        hosting.sizingOptions = []
        hosting.safeAreaRegions = []
        hosting.frame = NSRect(origin: .zero, size: size)
        hostingView = hosting

        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "permissions.window.title".localized
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.titlebarSeparatorStyle = .none
        win.backgroundColor = .windowBackgroundColor
        win.isReleasedWhenClosed = false
        win.isMovableByWindowBackground = false
        win.delegate = self
        win.standardWindowButton(.miniaturizeButton)?.isHidden = true
        win.standardWindowButton(.zoomButton)?.isHidden = true
        win.setFrame(NSRect(origin: .zero, size: size), display: false)
        win.contentView = PermissionWindowSurface(content: hosting, size: size)
        hosting.sizingOptions = []
        self.window = win

        checkForTransition()
        win.center()
        presentAnimated(win)
        startPolling()
    }

    private func makeContent() -> PermissionRequirementsView {
        PermissionRequirementsView(
            state: state,
            onActivate: { [weak self] in self?.handleActivate() },
            onClose: { [weak self] in self?.close() }
        )
    }

    private func presentAnimated(_ win: NSWindow) {
        win.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self, weak win] in
            guard let self, let win, self.window === win, win.isVisible else { return }
            self.checkForTransition()
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                win.alphaValue = 1
            } else {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    win.animator().alphaValue = 1
                }
            }
        }
    }

    override func close() {
        PermissionAssistant.shared.dismiss()
        window?.close()
    }

    private func handleActivate() {
        if AccessibilityPermission.isGranted {
            checkForTransition()
            return
        }
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
        guard window?.isVisible == true || hostingView != nil else { return }
        let current = readiness()
        if state.readiness != current { state.readiness = current }
        if state.readiness != .needsPermission { PermissionAssistant.shared.dismiss() }
        guard let window, hostingView != nil else { return }
        let language = LocalizationManager.shared.language
        if measuredReadiness != current || measuredLanguage != language {
            guard let size = measureContentSize() else { return }
            measuredSize = size
            measuredReadiness = current
            measuredLanguage = language
        }
        guard let measuredSize else { return }
        var frame = window.frame
        frame.origin.y = frame.maxY - measuredSize.height
        frame.size = measuredSize
        guard window.frame != frame else { return }
        window.setFrame(frame, display: true)
    }

    private func measureContentSize() -> NSSize? {
        let sizingView = NSHostingView(rootView: makeContent())
        sizingView.sizingOptions = .intrinsicContentSize
        sizingView.safeAreaRegions = []
        let size = sizingView.fittingSize
        guard size.height.isFinite, size.height > 0 else { return nil }
        return NSSize(width: PermissionRequirementsView.contentWidth, height: ceil(size.height))
    }

    // MARK: - NSWindowDelegate

    func windowDidChangeOcclusionState(_ notification: Notification) {
        if window?.occlusionState.contains(.visible) == true {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window?.occlusionState.contains(.visible) == true else { return }
                self.checkForTransition()
                self.startPolling()
            }
        } else {
            stopPolling()
        }
    }

    func windowWillClose(_ notification: Notification) {
        stopPolling()
        PermissionAssistant.shared.dismiss()
        hostingView = nil
        measuredSize = nil
        measuredReadiness = nil
        measuredLanguage = nil
        window?.contentView = nil
        window = nil
    }
}

private final class PermissionWindowSurface: NSView {
    init(content: NSView, size: NSSize) {
        super.init(frame: NSRect(origin: .zero, size: size))
        wantsLayer = true
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = permissionCGColor(.windowBackgroundColor)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
