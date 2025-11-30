import Cocoa
import ApplicationServices
import os

final class SystemActionRunner {
    
    private static let log = OSLog(subsystem: "com.tuapp.BuenMouse", category: "AppleScript")
    
    // MARK: - Space Management
    static func moveToNextSpace() {
        runAppleScript(source: "tell application \"System Events\" to key code 124 using {control down}")
    }
    
    static func moveToPreviousSpace() {
        runAppleScript(source: "tell application \"System Events\" to key code 123 using {control down}")
    }
    
    // MARK: - Mission Control
    static func activateMissionControl() {
        runAppleScript(source: "tell application \"Mission Control\" to launch")
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
    
    private static func runAppleScript(source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let err = error {
                    os_log("Error de AppleScript: %@", log: log, type: .error, err.description)
                }
            }
        }
    }
} 