// Archivo: ContentView.swift
// VERSIÓN FINAL CON DISEÑO MEJORADO Y TODAS LAS OPCIONES

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // --- Cabecera ---
            HStack {
                Image(systemName: "cursorarrow.and.square.on.square.dashed")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("BuenMouse")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Tu asistente de productividad.")
                        .foregroundColor(.secondary)
                }
            }
            
            // --- Descripción ---
            VStack(alignment: .leading, spacing: 10) {
                Text("Funciones Activas:")
                    .font(.headline)
                Label("Clic Central: Abrir Mission Control", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                Label("Arrastrar con Clic Central: Cambiar de Espacio", systemImage: "rectangle.split.2x1")
            }
            
            Divider()
            
            // --- Controles ---
            VStack(alignment: .leading, spacing: 15) {
                Text("Ajustes:")
                    .font(.headline)
                
                // Toggle para activar/desactivar la app.
                Toggle(isOn: $appDelegate.isMonitoringActive) {
                    Text("Activar monitoreo de gestos")
                }
                .toggleStyle(.switch)
                
                // Toggle para abrir al inicio.
                Toggle(isOn: $appDelegate.launchAtLogin) {
                    Text("Abrir BuenMouse al iniciar sesión")
                }
                .toggleStyle(.switch)
            }
            
            Spacer()
            
            // --- Botones de Acción ---
            HStack {
                // Botón para mover a la barra de menús.
                Button {
                    appDelegate.moveToMenuBar()
                } label: {
                    Label("Mover a la Barra de Menús", systemImage: "arrow.up.right.square")
                }
                
                Spacer()
                
                // Botón para salir.
                Button("Salir") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(30)
        .frame(width: 450, height: 380)
    }
}
