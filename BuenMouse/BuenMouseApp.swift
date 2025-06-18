// Archivo: BuenMouseApp.swift
// VERSIÓN COMPLETA CON VENTANA PRINCIPAL

import SwiftUI

@main
struct BuenMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate)
        }
    }
}
