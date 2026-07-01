import ApplicationServices
import Cocoa

/// Translates raw mouse events into BuenMouse gestures:
/// middle click → Mission Control, middle drag → switch Spaces,
/// and Ctrl + left drag → scroll.
final class GestureHandler {
    private weak var settingsManager: SettingsManager?
    private weak var scrollHandler: ScrollHandler?

    private enum GestureState {
        case idle
        case tracking(startLocation: CGPoint)
        case scrollingDrag(startLocation: CGPoint)
    }

    private var currentState: GestureState = .idle

    init(settingsManager: SettingsManager, scrollHandler: ScrollHandler) {
        self.settingsManager = settingsManager
        self.scrollHandler = scrollHandler
    }

    func resetState() {
        currentState = .idle
    }

    func handleEvent(type: CGEventType, event: CGEvent) -> EventResult {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let isControlPressed = event.flags.contains(.maskControl)
        let mouseLocation = event.location

        // Handle mouse up events
        if type == .leftMouseUp || type == .otherMouseUp {
            scrollHandler?.setControlClickScrolling(false)

            if case .scrollingDrag = currentState {
                currentState = .idle
            } else if case .tracking(let startLocation) = currentState, type == .otherMouseUp, buttonNumber == 2 {
                let dx = abs(mouseLocation.x - startLocation.x)
                let dy = abs(mouseLocation.y - startLocation.y)
                if hypot(dx, dy) < 5, settingsManager?.enableMissionControl == true {
                    SystemActionRunner.activateMissionControl()
                }
                currentState = .idle
                return .consumed
            } else {
                currentState = .idle
            }
        }

        switch currentState {
        case .idle:
            if type == .leftMouseDown && isControlPressed {
                currentState = .scrollingDrag(startLocation: mouseLocation)
                scrollHandler?.setControlClickScrolling(true)
                scrollHandler?.setLastControlClickTime(CFAbsoluteTimeGetCurrent())
                return .consumed
            }

            // Only claim the middle button while a middle-button gesture is
            // enabled; otherwise middle clicks keep their native behavior.
            if type == .otherMouseDown && buttonNumber == 2, middleButtonGesturesEnabled {
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
            if type == .otherMouseDragged {
                let deltaX = mouseLocation.x - startLocation.x
                let threshold = settingsManager?.dragThreshold ?? 100.0
                if abs(deltaX) > CGFloat(threshold) {
                    if settingsManager?.enableSpaceNavigation == true {
                        let invertDirection = settingsManager?.invertDragDirection ?? false
                        if deltaX > 0 {
                            invertDirection ? SystemActionRunner.moveToPreviousSpace() : SystemActionRunner.moveToNextSpace()
                        } else {
                            invertDirection ? SystemActionRunner.moveToNextSpace() : SystemActionRunner.moveToPreviousSpace()
                        }
                    }
                    currentState = .idle
                    return .consumed
                }
            }
        }

        return .passed
    }

    private var middleButtonGesturesEnabled: Bool {
        guard let settings = settingsManager else { return false }
        return settings.enableMissionControl || settings.enableSpaceNavigation
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
