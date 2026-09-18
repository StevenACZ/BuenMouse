import AppKit
import QuartzCore

/// Hosts the floating helper overlay shown over System Settings while the
/// user grants Accessibility access.
final class PermissionOverlayWindowController: NSWindowController {
    private var entering = false

    init(hostApp: PermissionHostApp, accentColor: NSColor, onClose: @escaping () -> Void) {
        let panel = PassiveOverlayPanel(
            contentRect: NSRect(origin: .zero, size: PermissionOverlayContentView.preferredSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)
        configureWindow(panel)
        panel.contentView = PermissionOverlayContentView(
            hostApp: hostApp,
            accentColor: accentColor,
            onClose: onClose
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(from sourceFrameInScreen: CGRect?, settingsFrame: CGRect, visibleFrame: CGRect) {
        guard let window else { return }

        guard let targetFrame = anchoredFrame(for: settingsFrame, visibleFrame: visibleFrame) else {
            hide()
            return
        }

        if let sourceFrameInScreen, !sourceFrameInScreen.isEmpty,
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        {
            entering = true
            window.alphaValue = 0.45
            window.setFrame(targetFrame.offsetBy(dx: 0, dy: 12), display: false)
            window.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(targetFrame, display: true)
                window.animator().alphaValue = 1
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated { self?.entering = false }
            }
        } else {
            window.alphaValue = 1
            window.setFrame(targetFrame, display: false)
            window.orderFrontRegardless()
        }
    }

    func updatePosition(with settingsFrame: CGRect, visibleFrame: CGRect) {
        guard !entering else { return }
        guard let target = anchoredFrame(for: settingsFrame, visibleFrame: visibleFrame) else {
            hide()
            return
        }
        if window?.frame != target { window?.setFrame(target, display: true) }
        if window?.isVisible != true { window?.orderFrontRegardless() }
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func configureWindow(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.animationBehavior = .none
    }

    private func anchoredFrame(for settingsFrame: CGRect, visibleFrame: CGRect) -> CGRect? {
        let sidebar = min(240, max(180, settingsFrame.width * 0.31))
        let left = ceil(max(settingsFrame.minX + sidebar + 16, visibleFrame.minX + 10))
        let right = floor(min(settingsFrame.maxX - 16, visibleFrame.maxX - 10))
        let bottom = ceil(max(settingsFrame.minY + 20, visibleFrame.minY + 10))
        let top = floor(min(settingsFrame.maxY - 20, visibleFrame.maxY - 10))
        guard right - left >= 300,
            let content = window?.contentView as? PermissionOverlayContentView
        else { return nil }
        let height = content.preferredHeight(for: right - left)
        guard top - bottom >= height else { return nil }
        return CGRect(x: left, y: bottom, width: right - left, height: height)
    }
}

private final class PassiveOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
