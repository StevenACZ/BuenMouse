// Archivo: SystemActionRunner.swift
// VERSIÓN COMPLETA Y FIABLE USANDO APPLESCRIPT

import Foundation

enum SystemActionRunner {
    
    static func activateMissionControl() {
        let scriptSource = "tell application \"Mission Control\" to launch"
        runAppleScript(source: scriptSource)
    }
    
    static func moveToNextSpace() {
        let scriptSource = """
        tell application "System Events"
            key code 124 using {control down}
        end tell
        """
        runAppleScript(source: scriptSource)
    }
    
    static func moveToPreviousSpace() {
        let scriptSource = """
        tell application "System Events"
            key code 123 using {control down}
        end tell
        """
        runAppleScript(source: scriptSource)
    }
    
    private static func runAppleScript(source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                
                if let err = error {
                    DispatchQueue.main.async {
                        print("Error de AppleScript: \(err)")
                    }
                }
            }
        }
    }
}
