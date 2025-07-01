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
            if startInMenubar { moveToMenuBar() }
        }
    }

    @Published var invertDragDirection = UserDefaults.standard.bool(forKey: "invertDragDirection") {
        didSet { UserDefaults.standard.set(invertDragDirection, forKey: "invertDragDirection") }
    }

    @Published var dragThreshold: Double = {
        let val = UserDefaults.standard.double(forKey: "dragThreshold")
        return max(0, min(500, val == 0 ? 40.0 : val))
    }() {
        didSet { UserDefaults.standard.set(dragThreshold, forKey: "dragThreshold") }
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

    private enum GestureState {
        case idle
        case tracking(startLocation: CGPoint)
        case dragging(startLocation: CGPoint)
        case scrollingDrag(startLocation: CGPoint)
    }

    private var currentState: GestureState = .idle
    private var eventTap: CFMachPort?
    private var cancellables = Set<AnyCancellable>()
    private var scrollAccumulator: Double = 0.0

    private var lastBackClickTimestamp: Double = 0
    private var cancelNextClickAsDoubleClick = false
    private var specialClickStartTime: Double = 0
    private var specialClickMoved = false

    var window: NSWindow?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ note: Notification) {
        requestPermissions()

        if UserDefaults.standard.bool(forKey: "startInMenubar") {
            moveToMenuBar()
        }

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in self?.spaceDidChange() }
            .store(in: &cancellables)

        isMonitoringActive = true
        configureMainWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopMonitoring()
    }

    private func configureMainWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = self.window ?? NSApplication.shared.windows.first {
                window.setContentSize(NSSize(width: 400, height: 500))
                window.center()
                window.styleMask.remove(.resizable)
            }
        }
    }

    private func requestPermissions() {
        if !AXIsProcessTrusted() {
            let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
            _ = AXIsProcessTrustedWithOptions(opts)
        }
    }

    private func spaceDidChange() {
        if isMonitoringActive { restartMonitoring() }
        currentState = .idle
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

    private func sendScroll(dx: CGFloat, dy: CGFloat) {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: src,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(dy),
            wheel2: Int32(dx),
            wheel3: 0
        )
        scrollEvent?.post(tap: .cghidEventTap)
    }

    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let flags = event.flags
        let isControlPressed = flags.contains(.maskControl)
        let specialButtonBack = 3
        let specialButtonForward = 4

        // ⛔️ CANCELA eventos ⌘← y ⌘→ nativos del sistema
        if type == .keyDown || type == .flagsChanged {
            if flags.contains(.maskCommand) {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                if keyCode == 123 || keyCode == 124 {
                    return nil
                }
            }
        }

        // ✅ ZOOM con Control + scroll
        if type == .scrollWheel {
            let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
            let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
            let isFromTrackpad = scrollPhase != 0 || momentumPhase != 0

            if invertScroll && !isFromTrackpad {
                let y = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                let x = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
                event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: -y)
                event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: -x)
            }

            if enableScrollZoom && isControlPressed {
                let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                scrollAccumulator += deltaY

                if scrollAccumulator >= 1.0 {
                    SystemActionRunner.zoomIn()
                    scrollAccumulator = 0.0
                } else if scrollAccumulator <= -1.0 {
                    SystemActionRunner.zoomOut()
                    scrollAccumulator = 0.0
                }
            }
        }

        // 🖱️ Back / Forward solo se activan al hacer clic
        if type == .otherMouseDown {
            if buttonNumber == specialButtonBack {
                specialClickStartTime = Double(event.timestamp) / Double(NSEC_PER_SEC)
            } else if buttonNumber == specialButtonForward {
                specialClickStartTime = Double(event.timestamp) / Double(NSEC_PER_SEC)
            }
        }

        if type == .otherMouseUp {
            if buttonNumber == specialButtonBack {
                SystemActionRunner.goBack()
                return nil
            } else if buttonNumber == specialButtonForward {
                SystemActionRunner.goForward()
                return nil
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
