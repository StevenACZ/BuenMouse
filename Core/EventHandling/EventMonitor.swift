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
    
    // Performance: Event batching system
    private struct EventBatch {
        let type: CGEventType
        let event: CGEvent
        let timestamp: TimeInterval
    }
    
    private var eventQueue: [EventBatch] = []
    private var batchTimer: Timer?
    private let batchProcessingQueue = DispatchQueue(label: "com.buenmouse.eventbatch", qos: .userInteractive)
    private let maxBatchSize = 10
    private let batchTimeout: TimeInterval = 0.001 // 1ms batching
    
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
        // Performance: For high-frequency events, use batching
        switch type {
        case .mouseMoved, .scrollWheel:
            // Batch high-frequency events
            return handleBatchedEvent(type: type, event: event)
            
        case .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            // Process critical events immediately
            return handleImmediateEvent(type: type, event: event)
            
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            // Process critical events immediately
            return handleImmediateEvent(type: type, event: event)
            
        default:
            // Unknown event type - pass through
            return Unmanaged.passUnretained(event)
        }
    }
    
    private func handleBatchedEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let batch = EventBatch(type: type, event: event, timestamp: CFAbsoluteTimeGetCurrent())
        
        batchProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.eventQueue.append(batch)
            
            // Process batch if it reaches max size
            if self.eventQueue.count >= self.maxBatchSize {
                self.processBatch()
            } else {
                // Schedule timer if not already running
                if self.batchTimer == nil {
                    DispatchQueue.main.async {
                        self.batchTimer = Timer.scheduledTimer(withTimeInterval: self.batchTimeout, repeats: false) { _ in
                            self.batchProcessingQueue.async {
                                self.processBatch()
                            }
                        }
                    }
                }
            }
        }
        
        // For batched events, we assume they might be consumed later
        return Unmanaged.passUnretained(event)
    }
    
    private func handleImmediateEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Process critical events immediately for responsiveness
        switch type {
        case .otherMouseDown, .otherMouseUp, .otherMouseDragged,
             .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            if let gestureHandler = gestureHandler {
                let result = gestureHandler.handleEvent(type: type, event: event)
                if result == .consumed {
                    return nil
                }
            }
        default:
            break
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func processBatch() {
        guard !eventQueue.isEmpty else { return }
        
        let currentBatch = eventQueue
        eventQueue.removeAll()
        batchTimer?.invalidate()
        batchTimer = nil
        
        // Process events in batch, filtering out duplicates and old events
        let now = CFAbsoluteTimeGetCurrent()
        let validEvents = currentBatch.filter { now - $0.timestamp < 0.1 } // Keep only recent events
        
        for eventBatch in validEvents {
            switch eventBatch.type {
            case .scrollWheel:
                if let scrollHandler = scrollHandler {
                    _ = scrollHandler.handleEvent(type: eventBatch.type, event: eventBatch.event)
                }
            case .mouseMoved:
                if let gestureHandler = gestureHandler {
                    _ = gestureHandler.handleEvent(type: eventBatch.type, event: eventBatch.event)
                }
            default:
                break
            }
        }
    }
    
    deinit {
        cleanup()
        os_log("EventMonitor deinitialized", log: .default, type: .info)
    }
}