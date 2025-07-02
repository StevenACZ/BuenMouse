import Cocoa
import ApplicationServices

final class GestureHandler: NSObject {
    private weak var settingsManager: SettingsManager?
    private weak var scrollHandler: ScrollHandler?
    
    // MARK: - Internal state
    private enum GestureState {
        case idle
        case tracking(startLocation: CGPoint)
        case scrollingDrag(startLocation: CGPoint)
    }

    private var currentState: GestureState = .idle
    private var lastBackEventTime: TimeInterval = 0
    private var lastForwardEventTime: TimeInterval = 0
    
    init(settingsManager: SettingsManager, scrollHandler: ScrollHandler) {
        self.settingsManager = settingsManager
        self.scrollHandler = scrollHandler
        super.init()
    }
    
    func resetState() {
        currentState = .idle
    }
    
    func handleEvent(type: CGEventType, event: CGEvent) -> EventResult {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let flags = event.flags
        let isControlPressed = flags.contains(.maskControl)
        let mouseLocation = event.location
        let now = CFAbsoluteTimeGetCurrent()

        let specialButtonBack = 3
        let specialButtonForward = 4

        // Handle mouse up events
        if type == .leftMouseUp || type == .otherMouseUp {
            scrollHandler?.setControlClickScrolling(false)

            if case .scrollingDrag(_) = currentState {
                currentState = .idle
            } else if case .tracking(let startLocation) = currentState, type == .otherMouseUp, buttonNumber == 2 {
                let dx = abs(mouseLocation.x - startLocation.x)
                let dy = abs(mouseLocation.y - startLocation.y)
                if hypot(dx, dy) < 5 {
                    SystemActionRunner.activateMissionControl()
                }
                currentState = .idle
                return .consumed
            } else {
                currentState = .idle
            }
        }

        // Handle gesture states
        switch currentState {
        case .idle:
            if type == .leftMouseDown && isControlPressed {
                currentState = .scrollingDrag(startLocation: mouseLocation)
                scrollHandler?.setControlClickScrolling(true)
                scrollHandler?.setLastControlClickTime(now)
                return .consumed
            }

            if type == .otherMouseDown && buttonNumber == 2 {
                currentState = .tracking(startLocation: mouseLocation)
                return .consumed
            }

        case .scrollingDrag(let lastLocation):
            if type == .leftMouseDragged {
                let dx = mouseLocation.x - lastLocation.x
                let dy = mouseLocation.y - lastLocation.y
                let scale: CGFloat = 0.7
                sendScroll(dx: -dx * scale, dy: -dy * scale)
                currentState = .scrollingDrag(startLocation: mouseLocation)
                return .consumed
            }

        case .tracking(let startLocation):
            if type == .otherMouseDragged || type == .mouseMoved {
                let deltaX = mouseLocation.x - startLocation.x
                let threshold = settingsManager?.dragThreshold ?? 40.0
                if abs(deltaX) > CGFloat(threshold) {
                    let invertDirection = settingsManager?.invertDragDirection ?? false
                    if deltaX > 0 {
                        invertDirection ? SystemActionRunner.moveToPreviousSpace() : SystemActionRunner.moveToNextSpace()
                    } else {
                        invertDirection ? SystemActionRunner.moveToNextSpace() : SystemActionRunner.moveToPreviousSpace()
                    }
                    currentState = .idle
                    return .consumed
                }
            }
        }

        // Handle special mouse buttons (back/forward)
        if type == .otherMouseDown {
            if buttonNumber == specialButtonBack && now - lastBackEventTime > 0.3 {
                lastBackEventTime = now
                SystemActionRunner.goBack()
                return .consumed
            } else if buttonNumber == specialButtonForward && now - lastForwardEventTime > 0.3 {
                lastForwardEventTime = now
                SystemActionRunner.goForward()
                return .consumed
            }
        }

        return .passed
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
} 