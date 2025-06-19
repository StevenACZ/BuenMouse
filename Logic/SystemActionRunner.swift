import Foundation
import AppKit
import os

enum SystemActionRunner {
    private static let log = OSLog(subsystem: "com.tuapp.BuenMouse", category: "AppleScript")

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
                    os_log("Error de AppleScript: %@", log: log, type: .error, err.description)
                }
            }
        }
    }
}
