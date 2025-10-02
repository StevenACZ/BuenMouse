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
    
    // MARK: - Robust button state tracking
    private struct ButtonState {
        var isPressed: Bool = false
        var lastDownTime: TimeInterval = 0
        var lastUpTime: TimeInterval = 0
        var pendingAction: Bool = false
        var clickCount: Int = 0
        var lastEventTime: TimeInterval = 0
    }
    
    private var backButtonState = ButtonState()
    private var forwardButtonState = ButtonState()
    
    // MARK: - Configuration constants
    private let debounceInterval: TimeInterval = 0.1 // Tiempo mínimo entre eventos válidos
    private let maxClickDuration: TimeInterval = 1.0 // Tiempo máximo para considerar un click válido
    private let minClickDuration: TimeInterval = 0.01 // Tiempo mínimo para evitar clicks accidentales
    private let eventClusterThreshold: TimeInterval = 0.05 // Tiempo para agrupar eventos duplicados
    
    init(settingsManager: SettingsManager, scrollHandler: ScrollHandler) {
        self.settingsManager = settingsManager
        self.scrollHandler = scrollHandler
        super.init()
    }
    
    func resetState() {
        currentState = .idle
        backButtonState = ButtonState()
        forwardButtonState = ButtonState()
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
                    // Only activate Mission Control if enabled in settings
                    if settingsManager?.enableMissionControl == true {
                        SystemActionRunner.activateMissionControl()
                    }
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
                    // Only switch spaces if enabled in settings
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

        // MARK: - Robust lateral button handling
        if buttonNumber == specialButtonBack {
            return handleLateralButton(
                type: type,
                buttonState: &backButtonState,
                action: { SystemActionRunner.goBack() },
                now: now
            )
        } else if buttonNumber == specialButtonForward {
            return handleLateralButton(
                type: type,
                buttonState: &forwardButtonState,
                action: { SystemActionRunner.goForward() },
                now: now
            )
        }

        return .passed
    }
    
    // MARK: - Robust button handling logic
    private func handleLateralButton(
        type: CGEventType,
        buttonState: inout ButtonState,
        action: @escaping () -> Void,
        now: TimeInterval
    ) -> EventResult {
        
        switch type {
        case .otherMouseDown:
            return handleButtonDown(buttonState: &buttonState, now: now)
            
        case .otherMouseUp:
            return handleButtonUp(buttonState: &buttonState, action: action, now: now)
            
        case .otherMouseDragged:
            // Si se arrastra, cancelamos cualquier acción pendiente
            buttonState.pendingAction = false
            return .consumed
            
        default:
            return .consumed
        }
    }
    
    private func handleButtonDown(buttonState: inout ButtonState, now: TimeInterval) -> EventResult {
        // Filtrar eventos duplicados por clustering temporal
        if now - buttonState.lastEventTime < eventClusterThreshold {
            // Evento duplicado dentro del cluster, lo ignoramos
            return .consumed
        }
        
        // Aplicar debounce si es necesario
        if now - buttonState.lastDownTime < debounceInterval {
            return .consumed
        }
        
        // Si el botón ya está "presionado", esto podría ser un evento duplicado
        if buttonState.isPressed {
            // Verificar si es un evento duplicado legítimo vs. un nuevo press
            let timeSinceLastDown = now - buttonState.lastDownTime
            if timeSinceLastDown < eventClusterThreshold {
                // Muy cerca del último down, probablemente duplicado
                return .consumed
            } else {
                // Tiempo suficiente, podría ser un nuevo press sin up previo
                // Reiniciamos el estado
                buttonState = ButtonState()
            }
        }
        
        // Registrar el nuevo down
        buttonState.isPressed = true
        buttonState.lastDownTime = now
        buttonState.lastEventTime = now
        buttonState.pendingAction = true
        buttonState.clickCount += 1
        
        return .consumed
    }
    
    private func handleButtonUp(
        buttonState: inout ButtonState,
        action: @escaping () -> Void,
        now: TimeInterval
    ) -> EventResult {
        
        // Filtrar eventos duplicados por clustering temporal
        if now - buttonState.lastEventTime < eventClusterThreshold {
            return .consumed
        }
        
        // Solo procesar si el botón estaba realmente presionado
        guard buttonState.isPressed else {
            return .consumed
        }
        
        let clickDuration = now - buttonState.lastDownTime
        
        // Verificar que la duración del click esté dentro de rangos válidos
        guard clickDuration >= minClickDuration && clickDuration <= maxClickDuration else {
            // Click demasiado corto (bounce) o demasiado largo (hold)
            buttonState.pendingAction = false
            buttonState.isPressed = false
            buttonState.lastEventTime = now
            return .consumed
        }
        
        // Ejecutar acción solo si está pendiente
        if buttonState.pendingAction {
            buttonState.pendingAction = false
            
            // Verificar debounce con el último up para evitar double-clicks accidentales
            if now - buttonState.lastUpTime >= debounceInterval {
                action()
            }
        }
        
        // Actualizar estado
        buttonState.isPressed = false
        buttonState.lastUpTime = now
        buttonState.lastEventTime = now
        
        return .consumed
    }
    
    // MARK: - Additional utility methods
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
    
    // MARK: - Debug and monitoring
    private func logButtonEvent(_ message: String, buttonState: ButtonState) {
        #if DEBUG
        print("Button Event: \(message) - Pressed: \(buttonState.isPressed), Pending: \(buttonState.pendingAction), Count: \(buttonState.clickCount)")
        #endif
    }
}

// MARK: - Additional improvements for event tap setup
extension GestureHandler {
    
    // Método para configurar el event tap con opciones optimizadas
    static func createEventTap(handler: @escaping CGEventTapCallBack) -> CFMachPort? {
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                       (1 << CGEventType.leftMouseUp.rawValue) |
                       (1 << CGEventType.leftMouseDragged.rawValue) |
                       (1 << CGEventType.otherMouseDown.rawValue) |
                       (1 << CGEventType.otherMouseUp.rawValue) |
                       (1 << CGEventType.otherMouseDragged.rawValue) |
                       (1 << CGEventType.mouseMoved.rawValue)
        
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: handler,
            userInfo: nil
        )
        
        return eventTap
    }
}