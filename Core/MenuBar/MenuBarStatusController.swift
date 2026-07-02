import AppKit
import SwiftUI
import os.log

/// Owns the status item, the dropdown panel (an NSPopover with SwiftUI
/// content), and the auxiliary windows (Settings, About). The panel is
/// transient — it closes when the user clicks anywhere else — and its height
/// always hugs the SwiftUI content.
@MainActor
final class MenuBarStatusController: NSObject, NSPopoverDelegate, NSWindowDelegate {
    private let settings: SettingsManager

    /// Set by the AppDelegate — opens the Accessibility onboarding window.
    var onOpenPermissions: (() -> Void)?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var isPopoverTransitioning = false

    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

    init(settings: SettingsManager) {
        self.settings = settings
        super.init()
    }

    func start() {
        setupStatusItem()
        setupPopover()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = currentStatusImage()
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func refreshStatusIcon() {
        statusItem?.button?.image = currentStatusImage()
    }

    private func currentStatusImage() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let active = settings.isMonitoringActive && AccessibilityPermission.isGranted
        let name = active ? "computermouse.fill" : "computermouse"
        let description = active ? "statusitem.active".localized : "statusitem.paused".localized
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    /// Squash-and-overshoot bounce on every status button press.
    private func animateStatusButton(_ button: NSStatusBarButton) {
        button.wantsLayer = true
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1.0, 0.86, 1.08, 1.0]
        animation.keyTimes = [0, 0.35, 0.75, 1]
        animation.duration = 0.28
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
        ]
        button.layer?.add(animation, forKey: "buenMouseStatusPress")
    }

    // MARK: - Popover

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: makePanelHost())
        self.popover = popover
        refreshPopoverSize()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        guard !isPopoverTransitioning else { return }
        lockPopoverTransition()
        animateStatusButton(button)

        if popover.isShown {
            closePopover()
        } else {
            // Refresh the root view on every open: permission state or
            // settings may have changed since the last look.
            if let hosting = popover.contentViewController as? NSHostingController<MenuBarPanelHost> {
                hosting.rootView = makePanelHost()
            } else {
                popover.contentViewController = NSHostingController(rootView: makePanelHost())
            }
            refreshPopoverSize()
            button.state = .on
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { [weak self] in
                self?.refreshPopoverSize()
            }
        }
    }

    func closePopover() {
        popover?.performClose(nil)
        statusItem?.button?.state = .off
    }

    func popoverWillClose(_ notification: Notification) {
        statusItem?.button?.state = .off
    }

    /// Debounce so a fast double-click can't fire show and close mid-animation.
    private func lockPopoverTransition() {
        isPopoverTransitioning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.isPopoverTransitioning = false
        }
    }

    /// The panel height always hugs the SwiftUI content at a fixed width.
    private func refreshPopoverSize() {
        guard let popover,
            let hosting = popover.contentViewController as? NSHostingController<MenuBarPanelHost>
        else { return }
        let width = Theme.Layout.panelWidth
        let fitting = hosting.sizeThatFits(in: NSSize(width: width, height: .greatestFiniteMagnitude))
        let height = min(max(ceil(fitting.height), 1), 680)
        popover.contentSize = NSSize(width: width, height: height)
        hosting.view.setFrameSize(popover.contentSize)
        hosting.view.layoutSubtreeIfNeeded()
    }

    private func makePanelHost() -> MenuBarPanelHost {
        MenuBarPanelHost(
            settings: settings,
            isPermissionGranted: AccessibilityPermission.isGranted,
            openSettings: { [weak self] in self?.openSettingsWindow() },
            openAbout: { [weak self] in self?.openAboutWindow() },
            openPermissions: { [weak self] in
                self?.closePopover()
                self?.onOpenPermissions?()
            },
            quit: { NSApplication.shared.terminate(nil) }
        )
    }

    // MARK: - Windows

    func openSettingsWindow() {
        closePopover()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.settingsWindow = self.present(
                window: self.settingsWindow,
                rootView: SettingsView(settings: self.settings),
                autosaveName: "BuenMouseSettingsWindow"
            )
        }
    }

    func openAboutWindow() {
        closePopover()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.aboutWindow = self.present(
                window: self.aboutWindow,
                rootView: AboutView(),
                autosaveName: "BuenMouseAboutWindow"
            )
        }
    }

    /// Presents a cached window with freshly-built SwiftUI content sized to
    /// fit. Rebuilding the hosting view on every show keeps animations fluid
    /// and guarantees the previous content (and its timers) is torn down.
    private func present<Content: View>(window: NSWindow?, rootView: Content, autosaveName: String) -> NSWindow {
        let hosting = NSHostingController(rootView: rootView)
        let target: NSWindow

        if let window {
            target = window
        } else {
            target = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            target.titleVisibility = .hidden
            target.titlebarAppearsTransparent = true
            target.isReleasedWhenClosed = false
            target.standardWindowButton(.miniaturizeButton)?.isHidden = true
            target.standardWindowButton(.zoomButton)?.isHidden = true
            target.delegate = self
            target.setFrameAutosaveName(autosaveName)
        }

        let wasVisible = target.isVisible
        target.contentViewController = hosting
        target.setContentSize(hosting.view.fittingSize)
        if !wasVisible {
            target.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        target.makeKeyAndOrderFront(nil)
        return target
    }

    /// Drop the SwiftUI content when a window closes so its state and timers
    /// don't keep running while hidden — this app stays alive for weeks.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        window.contentViewController = nil
    }
}
