// Archivo: BuenMouse2App.swift
// VERSIÓN CON VENTANA PRINCIPAL

import SwiftUI

@main
struct BuenMouseApp: App {
    // Inyectamos nuestro AppDelegate para que esté disponible en toda la app.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            // La ventana principal mostrará nuestra ContentView.
            ContentView()
                // Hacemos que la instancia del AppDelegate esté disponible para la ContentView y sus hijas.
                .environmentObject(appDelegate)
        }
    }
}
