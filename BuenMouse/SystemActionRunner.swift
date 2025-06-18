// Archivo: SystemActionRunner.swift
// VERSIÓN FINAL Y FIABLE USANDO APPLESCRIPT PARA TODAS LAS ACCIONES

import Foundation

enum SystemActionRunner {
    
    // --- Acción para Mission Control ---
    static func activateMissionControl() {
        let scriptSource = "tell application \"Mission Control\" to launch"
        runAppleScript(source: scriptSource)
    }
    
    // --- Acción para Mover al Espacio SIGUIENTE ---
    static func moveToNextSpace() {
        print("Enviando comando de AppleScript para cambiar al espacio derecho.")
        // Este script usa los key codes que ya verificaste que funcionan (124 = Flecha Derecha).
        let scriptSource = """
        tell application "System Events"
            key code 124 using {control down}
        end tell
        """
        runAppleScript(source: scriptSource)
    }
    
    // --- Acción para Mover al Espacio ANTERIOR ---
    static func moveToPreviousSpace() {
        print("Enviando comando de AppleScript para cambiar al espacio izquierdo.")
        // 123 = Flecha Izquierda
        let scriptSource = """
        tell application "System Events"
            key code 123 using {control down}
        end tell
        """
        runAppleScript(source: scriptSource)
    }
    
    // --- Función de Ayuda Genérica para Ejecutar AppleScript ---
    private static func runAppleScript(source: String) {
        // Ejecutamos en un hilo de fondo para no bloquear la app.
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                
                if let err = error {
                    // Imprimimos cualquier error en el hilo principal para depuración.
                    DispatchQueue.main.async {
                        print("Error de AppleScript: \(err)")
                    }
                }
            }
        }
    }
}
