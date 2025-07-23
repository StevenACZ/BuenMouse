import Cocoa
import ApplicationServices

private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let myself = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return myself.handleEvent(proxy: proxy, type: type, event: event)
}

final class EventMonitor: NSObject {
    private var eventTap: CFMachPort?
    private weak var gestureHandler: GestureHandler?
    private weak var scrollHandler: ScrollHandler?
    
    init(gestureHandler: GestureHandler, scrollHandler: ScrollHandler) {
        self.gestureHandler = gestureHandler
        self.scrollHandler = scrollHandler
        super.init()
    }
    
    func startMonitoring() {
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

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }
    
    func requestPermissions() {
        if !AXIsProcessTrusted() {
            let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
            _ = AXIsProcessTrustedWithOptions(opts)
        }
    }
    
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Early return for performance - only process relevant events
        switch type {
        case .otherMouseDown, .otherMouseUp, .otherMouseDragged,
             .leftMouseDown, .leftMouseUp, .leftMouseDragged,
             .scrollWheel:
            break
        default:
            return Unmanaged.passUnretained(event)
        }
        
        // Delegate to gesture handler first (more common)
        if let gestureHandler = gestureHandler {
            let result = gestureHandler.handleEvent(type: type, event: event)
            if result == .consumed {
                return nil
            }
        }
        
        // Delegate to scroll handler
        if let scrollHandler = scrollHandler {
            let result = scrollHandler.handleEvent(type: type, event: event)
            if result == .consumed {
                return nil
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
} 