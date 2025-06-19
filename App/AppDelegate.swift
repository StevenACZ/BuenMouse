import Cocoa
import ApplicationServices
import ServiceManagement
import Combine

private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let myself = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
    return myself.handleEvent(proxy: proxy, type: type, event: event)
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, SettingsProtocol {

    @Published var isMonitoringActive = false {
        didSet { isMonitoringActive ? startMonitoring() : stopMonitoring() }
    }

    @Published var launchAtLogin = (SMAppService.mainApp.status == .enabled) {
        didSet { launchAtLogin ? ServiceManager.register() : ServiceManager.unregister() }
    }

    @Published var startInMenubar = UserDefaults.standard.bool(forKey: "startInMenubar") {
        didSet {
            UserDefaults.standard.set(startInMenubar, forKey: "startInMenubar")
            if startInMenubar {
                moveToMenuBar()
            }
        }
    }

    @Published var invertDragDirection = UserDefaults.standard.bool(forKey: "invertDragDirection") {
        didSet { UserDefaults.standard.set(invertDragDirection, forKey: "invertDragDirection") }
    }

    @Published var dragThreshold: Double = {
        let val = UserDefaults.standard.double(forKey: "dragThreshold")
        return val == 0 ? 40.0 : val
    }() {
        didSet {
            if dragThreshold < 5 { dragThreshold = 5 }
            UserDefaults.standard.set(dragThreshold, forKey: "dragThreshold")
        }
    }

    @Published var invertScroll = UserDefaults.standard.bool(forKey: "invertScroll") {
        didSet {
            UserDefaults.standard.set(invertScroll, forKey: "invertScroll")
            restartMonitoring()
        }
    }

    @Published var enableScrollZoom = UserDefaults.standard.bool(forKey: "enableScrollZoom") {
        didSet {
            UserDefaults.standard.set(enableScrollZoom, forKey: "enableScrollZoom")
        }
    }

    @Published var zoomThreshold: Double = {
        let val = UserDefaults.standard.double(forKey: "zoomThreshold")
        return val == 0 ? 2.0 : val
    }() {
        didSet {
            if zoomThreshold < 0.5 { zoomThreshold = 0.5 }
            UserDefaults.standard.set(zoomThreshold, forKey: "zoomThreshold")
        }
    }

    private enum GestureState {
        case idle
        case tracking(startLocation: CGPoint)
        case dragging(startLocation: CGPoint)
        case inMissionControl
    }

    private var currentState: GestureState = .idle
    private var eventTap: CFMachPort?
    private var cancellables = Set<AnyCancellable>()
    var window: NSWindow?
    var statusItem: NSStatusItem?

    private var scrollAccumulator: Double = 0.0

    func applicationDidFinishLaunching(_ note: Notification) {
        requestPermissions()

        if UserDefaults.standard.bool(forKey: "startInMenubar") {
            moveToMenuBar()
        }

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in self?.spaceDidChange() }
            .store(in: &cancellables)

        isMonitoringActive = true

        DispatchQueue.main.async { [weak self] in
            if let window = self?.window ?? NSApplication.shared.windows.first {
                window.setContentSize(NSSize(width: 400, height: 500))
                window.center()
                window.styleMask.remove(.resizable)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopMonitoring()
    }

    private func requestPermissions() {
        if !AXIsProcessTrusted() {
            let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
            _ = AXIsProcessTrustedWithOptions(opts)
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility permissions required"
                alert.informativeText = "Please enable BuenMouse in System Preferences > Security & Privacy > Accessibility."
                alert.runModal()
            }
        }
    }

    private func spaceDidChange() {
        if isMonitoringActive { restartMonitoring() }
        if case .inMissionControl = currentState { currentState = .idle }
    }

    private func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }

    private func startMonitoring() {
        guard eventTap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        if let tap = eventTap {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
            currentState = .idle
        }
    }

    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .scrollWheel {
            let flags = event.flags
            let isControlPressed = flags.contains(.maskControl)

            if invertScroll {
                let y = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: -y)
                let x = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
                event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: -x)
            }

            if enableScrollZoom && isControlPressed {
                let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                scrollAccumulator += deltaY

                if scrollAccumulator >= zoomThreshold {
                    SystemActionRunner.zoomIn()
                    scrollAccumulator = 0.0
                } else if scrollAccumulator <= -zoomThreshold {
                    SystemActionRunner.zoomOut()
                    scrollAccumulator = 0.0
                }
            }
        }

        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        guard buttonNumber == 2 else { return Unmanaged.passUnretained(event) }

        switch currentState {
        case .idle:
            if type == .otherMouseDown {
                currentState = .tracking(startLocation: event.location)
            }

        case .tracking(let startLocation):
            if type == .otherMouseUp {
                SystemActionRunner.activateMissionControl()
                currentState = .idle
            } else if type == .mouseMoved || type == .otherMouseDragged {
                if hypot(event.location.x - startLocation.x, event.location.y - startLocation.y) > 8.0 {
                    currentState = .dragging(startLocation: startLocation)
                }
            }

        case .dragging(let startLocation):
            if type == .otherMouseUp {
                currentState = .idle
            } else if type == .mouseMoved || type == .otherMouseDragged {
                let deltaX = event.location.x - startLocation.x
                if abs(deltaX) > CGFloat(dragThreshold) {
                    if deltaX > 0 {
                        invertDragDirection ? SystemActionRunner.moveToPreviousSpace() : SystemActionRunner.moveToNextSpace()
                    } else {
                        invertDragDirection ? SystemActionRunner.moveToNextSpace() : SystemActionRunner.moveToPreviousSpace()
                    }
                    currentState = .idle
                }
            }

        case .inMissionControl:
            if type == .otherMouseDown {
                SystemActionRunner.activateMissionControl()
                currentState = .idle
            }
        }

        return Unmanaged.passUnretained(event)
    }

    func moveToMenuBar() {
        window?.close()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        UserDefaults.standard.set(true, forKey: "startInMenubar")
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.click.badge.clock", accessibilityDescription: "BuenMouse")
            button.action = #selector(showMainWindow)
            button.target = self
            button.setAccessibilityLabel("BuenMouse icon")
            button.setAccessibilityHelp("Click to open main window")
        }
    }

    @objc func showMainWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        statusItem = nil
        UserDefaults.standard.set(false, forKey: "startInMenubar")
    }
}
