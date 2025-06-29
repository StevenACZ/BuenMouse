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

    static func zoomIn() {
        sendKeyCombo(keyCode: 24, flags: [.maskCommand]) // Cmd +
    }

    static func zoomOut() {
        sendKeyCombo(keyCode: 27, flags: [.maskCommand]) // Cmd -
    }

    static func goBack() {
        simulateKeyPress(keyCode: 123, flags: .maskCommand) // ⌘ + ←
    }

    static func goForward() {
        simulateKeyPress(keyCode: 124, flags: .maskCommand) // ⌘ + →
    }

    private static func sendKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }

    private static func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }

        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags

        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags

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
