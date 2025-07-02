import Cocoa
import ApplicationServices

enum EventResult {
    case consumed
    case passed
}

final class ScrollHandler: NSObject {
    private weak var settingsManager: SettingsManager?
    
    private var scrollAccumulator: Double = 0.0
    private var isControlClickScrolling = false
    private var lastControlClickTime: TimeInterval = 0
    
    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        super.init()
    }
    
    func setControlClickScrolling(_ value: Bool) {
        isControlClickScrolling = value
    }
    
    func setLastControlClickTime(_ time: TimeInterval) {
        lastControlClickTime = time
    }
    
    func handleEvent(type: CGEventType, event: CGEvent) -> EventResult {
        guard type == .scrollWheel else { return .passed }
        
        let flags = event.flags
        let isControlPressed = flags.contains(.maskControl)
        let now = CFAbsoluteTimeGetCurrent()
        
        // Handle scroll inversion
        let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        let isFromTrackpad = scrollPhase != 0 || momentumPhase != 0

        if settingsManager?.invertScroll == true && !isFromTrackpad {
            let y = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
            let x = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
            event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: -y)
            event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: -x)
        }

        // Handle scroll zoom
        let timeSinceControlClick = now - lastControlClickTime
        if settingsManager?.enableScrollZoom == true && isControlPressed && !isControlClickScrolling && timeSinceControlClick > 0.2 {
            let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
            scrollAccumulator += deltaY

            if scrollAccumulator >= 1.0 {
                SystemActionRunner.zoomIn()
                scrollAccumulator = 0.0
                return .consumed
            } else if scrollAccumulator <= -1.0 {
                SystemActionRunner.zoomOut()
                scrollAccumulator = 0.0
                return .consumed
            }
        }
        
        return .passed
    }
} 