import Cocoa
import ApplicationServices
import SwiftUI

private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let myself = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
    return myself.handleEvent(proxy: proxy, type: type, event: event)
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, SettingsProtocol {
    // MARK: - Persisted Settings
    @Published var isMonitoringActive: Bool = UserDefaults.standard.bool(forKey: "isMonitoringActive") {
        didSet { UserDefaults.standard.set(isMonitoringActive, forKey: "isMonitoringActive") }
    }

    @Published var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: "launchAtLogin") {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    @Published var startInMenubar: Bool = UserDefaults.standard.bool(forKey: "startInMenubar") {
        didSet { UserDefaults.standard.set(startInMenubar, forKey: "startInMenubar") }
    }

    @Published var invertDragDirection: Bool = UserDefaults.standard.bool(forKey: "invertDragDirection") {
        didSet { UserDefaults.standard.set(invertDragDirection, forKey: "invertDragDirection") }
    }

    @Published var dragThreshold: Double = {
        let value = UserDefaults.standard.double(forKey: "dragThreshold")
        return value == 0 ? 40.0 : value
    }() {
        didSet { UserDefaults.standard.set(dragThreshold, forKey: "dragThreshold") }
    }

    @Published var invertScroll: Bool = UserDefaults.standard.bool(forKey: "invertScroll") {
        didSet { UserDefaults.standard.set(invertScroll, forKey: "invertScroll") }
    }

    @Published var enableScrollZoom: Bool = UserDefaults.standard.bool(forKey: "enableScrollZoom") {
        didSet { UserDefaults.standard.set(enableScrollZoom, forKey: "enableScrollZoom") }
    }

    func moveToMenuBar() {}

    var window: NSWindow?

    // MARK: - Internal state
    private enum GestureState {
        case idle
        case tracking(startLocation: CGPoint)
        case scrollingDrag(startLocation: CGPoint)
    }

    private var currentState: GestureState = .idle
    private var eventTap: CFMachPort?
    private var scrollAccumulator: Double = 0.0
    private var isControlClickScrolling = false
    private var lastBackEventTime: TimeInterval = 0
    private var lastForwardEventTime: TimeInterval = 0
    private var lastControlClickTime: TimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestPermissions()
        startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopMonitoring()
    }

    private func requestPermissions() {
        if !AXIsProcessTrusted() {
            let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
            _ = AXIsProcessTrustedWithOptions(opts)
        }
    }

    private func startMonitoring() {
        guard eventTap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
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
        let mouseLocation = event.location
        let now = CFAbsoluteTimeGetCurrent()

        let specialButtonBack = 3
        let specialButtonForward = 4

        if type == .keyDown || type == .flagsChanged {
            if flags.contains(.maskCommand) {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                if keyCode == 123 || keyCode == 124 {
                    return nil
                }
            }
        }

        if type == .leftMouseUp || type == .otherMouseUp {
            isControlClickScrolling = false

            if case .scrollingDrag(_) = currentState {
                currentState = .idle
            } else if case .tracking(let startLocation) = currentState, type == .otherMouseUp, buttonNumber == 2 {
                let dx = abs(mouseLocation.x - startLocation.x)
                let dy = abs(mouseLocation.y - startLocation.y)
                if hypot(dx, dy) < 5 {
                    SystemActionRunner.activateMissionControl()
                }
                currentState = .idle
                return nil
            } else {
                currentState = .idle
            }
        }

        switch currentState {
        case .idle:
            if type == .leftMouseDown && isControlPressed {
                currentState = .scrollingDrag(startLocation: mouseLocation)
                isControlClickScrolling = true
                lastControlClickTime = now
                return nil
            }

            if type == .otherMouseDown && buttonNumber == 2 {
                currentState = .tracking(startLocation: mouseLocation)
                return nil
            }

        case .scrollingDrag(let lastLocation):
            if type == .leftMouseDragged {
                let dx = mouseLocation.x - lastLocation.x
                let dy = mouseLocation.y - lastLocation.y
                let scale: CGFloat = 0.7
                sendScroll(dx: -dx * scale, dy: -dy * scale)
                currentState = .scrollingDrag(startLocation: mouseLocation)
                return nil
            }

        case .tracking(let startLocation):
            if type == .otherMouseDragged || type == .mouseMoved {
                let deltaX = mouseLocation.x - startLocation.x
                if abs(deltaX) > CGFloat(dragThreshold) {
                    if deltaX > 0 {
                        invertDragDirection ? SystemActionRunner.moveToPreviousSpace() : SystemActionRunner.moveToNextSpace()
                    } else {
                        invertDragDirection ? SystemActionRunner.moveToNextSpace() : SystemActionRunner.moveToPreviousSpace()
                    }
                    currentState = .idle
                    return nil
                }
            }
        }

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

            let timeSinceControlClick = now - lastControlClickTime
            if enableScrollZoom && isControlPressed && !isControlClickScrolling && timeSinceControlClick > 0.2 {
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

        if type == .otherMouseDown {
            if buttonNumber == specialButtonBack && now - lastBackEventTime > 0.3 {
                lastBackEventTime = now
                SystemActionRunner.goBack()
            } else if buttonNumber == specialButtonForward && now - lastForwardEventTime > 0.3 {
                lastForwardEventTime = now
                SystemActionRunner.goForward()
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
