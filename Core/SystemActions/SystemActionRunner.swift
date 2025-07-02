import Cocoa
import ApplicationServices

final class SystemActionRunner {
    
    // MARK: - Space Management
    static func moveToNextSpace() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: false)
        
        keyDown?.flags = .maskControl
        keyUp?.flags = .maskControl
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    static func moveToPreviousSpace() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 123, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 123, keyDown: false)
        
        keyDown?.flags = .maskControl
        keyUp?.flags = .maskControl
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Mission Control
    static func activateMissionControl() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 160, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 160, keyDown: false)
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Navigation
    static func goBack() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 123, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 123, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    static func goForward() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Zoom
    static func zoomIn() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 24, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 24, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    static func zoomOut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 27, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 27, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
} 