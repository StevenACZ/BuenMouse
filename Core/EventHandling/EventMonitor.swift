import ApplicationServices
import Cocoa
import os.log

private func eventTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }
    let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.handleEvent(proxy: proxy, type: type, event: event)
}

/// Owns the CGEvent tap that powers every gesture. The app can stay running
/// for weeks, so the tap only listens to the events gestures actually need
/// and re-enables itself if macOS disables it (timeout or user input).
final class EventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let gestureHandler: GestureHandler
    private let scrollHandler: ScrollHandler

    /// `mouseMoved` is intentionally NOT tapped: middle-button drags arrive as
    /// `otherMouseDragged`, so plain cursor movement never wakes the process.
    private static let eventMask: CGEventMask =
        (1 << CGEventType.otherMouseDown.rawValue)
        | (1 << CGEventType.otherMouseUp.rawValue)
        | (1 << CGEventType.otherMouseDragged.rawValue)
        | (1 << CGEventType.leftMouseDown.rawValue)
        | (1 << CGEventType.leftMouseUp.rawValue)
        | (1 << CGEventType.leftMouseDragged.rawValue)
        | (1 << CGEventType.scrollWheel.rawValue)

    init(gestureHandler: GestureHandler, scrollHandler: ScrollHandler) {
        self.gestureHandler = gestureHandler
        self.scrollHandler = scrollHandler
    }

    var isMonitoring: Bool { eventTap != nil }

    func startMonitoring() {
        guard eventTap == nil else { return }

        guard AXIsProcessTrusted() else {
            os_log("Cannot start monitoring: accessibility permission not granted", log: .default, type: .error)
            return
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else {
            os_log("Failed to create event tap", log: .default, type: .error)
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let source = runLoopSource else {
            os_log("Failed to create run loop source", log: .default, type: .error)
            cleanup()
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        os_log("EventMonitor started", log: .default, type: .info)
    }

    func stopMonitoring() {
        guard eventTap != nil else { return }
        cleanup()
        gestureHandler.resetState()
        os_log("EventMonitor stopped", log: .default, type: .info)
    }

    /// Cheap safety net after sleep/wake: if the tap exists but macOS left it
    /// disabled, turn it back on.
    func reassertTap() {
        guard let tap = eventTap, !CGEvent.tapIsEnabled(tap: tap) else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        gestureHandler.resetState()
        os_log("Event tap re-enabled after wake", log: .default, type: .info)
    }

    private func cleanup() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS disables slow or user-interrupted taps. For an always-on
            // app this must never be terminal — re-enable and reset gestures.
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                os_log("Event tap re-enabled after system disable", log: .default, type: .info)
            }
            gestureHandler.resetState()
            return Unmanaged.passUnretained(event)

        case .scrollWheel:
            return scrollHandler.handleEvent(type: type, event: event) == .consumed
                ? nil
                : Unmanaged.passUnretained(event)

        case .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            return gestureHandler.handleEvent(type: type, event: event) == .consumed
                ? nil
                : Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    deinit {
        cleanup()
    }
}
