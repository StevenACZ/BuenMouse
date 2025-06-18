// Archivo: SystemActionRunner.swift
// VERSIÓN SIMPLE Y ESTABLE

import Foundation
import AppKit

enum SystemActionRunner {
    
    static func activateMissionControl() {
        runAppleScript(source: "tell application \"Mission Control\" to launch")
    }
    
    static func moveToNextSpace() {
        runAppleScript(source: "tell application \"System Events\" to key code 124 using {control down}")
    }
    
    static func moveToPreviousSpace() {
        runAppleScript(source: "tell application \"System Events\" to key code 123 using {control down}")
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
