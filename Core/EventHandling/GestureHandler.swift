import ApplicationServices
import Cocoa

/// Translates middle-button mouse events into BuenMouse gestures:
/// middle click → Mission Control and middle drag → switch Spaces.
///
/// Nothing here reacts to the left button: Ctrl + left click is the system
/// secondary click, so claiming it would suppress contextual menus
/// session-wide.
final class GestureHandler {
    private weak var settingsManager: SettingsManager?

    private enum GestureState {
        case idle
        case tracking(startLocation: CGPoint)
    }

    private var currentState: GestureState = .idle

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    func resetState() {
        currentState = .idle
    }

    func handleEvent(type: CGEventType, event: CGEvent) -> EventResult {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let mouseLocation = event.location

        if type == .otherMouseUp {
            if case .tracking(let startLocation) = currentState, buttonNumber == 2 {
                let dx = abs(mouseLocation.x - startLocation.x)
                let dy = abs(mouseLocation.y - startLocation.y)
                if hypot(dx, dy) < 5, settingsManager?.enableMissionControl == true {
                    SystemActionRunner.activateMissionControl()
                }
                currentState = .idle
                return .consumed
            }
            currentState = .idle
        }

        switch currentState {
        case .idle:
            // Only claim the middle button while a middle-button gesture is
            // enabled; otherwise middle clicks keep their native behavior.
            if type == .otherMouseDown && buttonNumber == 2, middleButtonGesturesEnabled {
                currentState = .tracking(startLocation: mouseLocation)
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
}
