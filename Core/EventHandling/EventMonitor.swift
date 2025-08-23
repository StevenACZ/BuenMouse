import Cocoa
import ApplicationServices
import os.log

private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { 
        os_log("Event tap callback called with nil refcon", log: .default, type: .error)
        return Unmanaged.passUnretained(event) 
    }
    
    let myself = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return myself.handleEvent(proxy: proxy, type: type, event: event)
}

final class EventMonitor: NSObject {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var gestureHandler: GestureHandler?
    private weak var scrollHandler: ScrollHandler?
    private var isMonitoring = false
    
    // Performance optimization: Pre-computed event mask
    private static let eventMask: CGEventMask = {
        let mask: CGEventMask = 
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        return mask
    }()
    
    init(gestureHandler: GestureHandler, scrollHandler: ScrollHandler) {
        self.gestureHandler = gestureHandler
        self.scrollHandler = scrollHandler
        super.init()
        os_log("EventMonitor initialized", log: .default, type: .info)
    }
    
    func startMonitoring() {
        guard eventTap == nil else { 
            os_log("EventMonitor already monitoring", log: .default, type: .info)
            return 
        }
        
        guard AXIsProcessTrusted() else {
            os_log("Cannot start monitoring: accessibility permissions not granted", log: .default, type: .error)
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
        isMonitoring = true
        
        os_log("EventMonitor started successfully", log: .default, type: .info)
    }

    func stopMonitoring() {
        guard isMonitoring else {
            os_log("EventMonitor not currently monitoring", log: .default, type: .info)
            return
        }
        
        cleanup()
        os_log("EventMonitor stopped", log: .default, type: .info)
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
        isMonitoring = false
    }
    
    func requestPermissions() {
        let isTrusted = AXIsProcessTrusted()
        os_log("Checking accessibility permissions: %{public}@", log: .default, type: .info, isTrusted ? "granted" : "not granted")
        
        if !isTrusted {
            os_log("Requesting accessibility permissions...", log: .default, type: .info)
            let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
            _ = AXIsProcessTrustedWithOptions(opts)
        }
    }
    
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Performance optimization: inline switch for fastest path
        switch type {
        case .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            // Gesture events - handle first as they're more common
            if let gestureHandler = gestureHandler {
                let result = gestureHandler.handleEvent(type: type, event: event)
                if result == .consumed {
                    return nil
                }
            }
            
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            // Mouse events that may involve gestures
            if let gestureHandler = gestureHandler {
                let result = gestureHandler.handleEvent(type: type, event: event)
                if result == .consumed {
                    return nil
                }
            }
            
        case .scrollWheel:
            // Scroll events - delegate to scroll handler
            if let scrollHandler = scrollHandler {
                let result = scrollHandler.handleEvent(type: type, event: event)
                if result == .consumed {
                    return nil
                }
            }
            
        case .mouseMoved:
            // Only handle if we're in a gesture state
            if let gestureHandler = gestureHandler {
                let result = gestureHandler.handleEvent(type: type, event: event)
                if result == .consumed {
                    return nil
                }
            }
            
        default:
            // Unknown event type - pass through
            return Unmanaged.passUnretained(event)
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    deinit {
        cleanup()
        os_log("EventMonitor deinitialized", log: .default, type: .info)
    }
}