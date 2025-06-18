// Archivo: ContentView.swift
// VERSIÓN FINAL CON RANGO DE SLIDER MÁXIMO

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
            .padding(.bottom, 10)
            
            Divider()
            
            // --- Controles ---
            VStack(alignment: .leading, spacing: 15) {
                Text("Ajustes:")
                    .font(.headline)
                
                Toggle(isOn: $appDelegate.isMonitoringActive) {
                    Text("Activar monitoreo de gestos")
                }
                .toggleStyle(.switch)
                
                Toggle(isOn: $appDelegate.launchAtLogin) {
                    Text("Abrir BuenMouse al iniciar sesión")
                }
                .toggleStyle(.switch)
                
                Toggle(isOn: $appDelegate.invertDragDirection) {
                    Text("Invertir dirección de arrastre para espacios")
                }
                .toggleStyle(.switch)
                
                // --- SLIDER DE SENSIBILIDAD CON RANGO MÁXIMO ---
                VStack(alignment: .leading) {
                    Text("Sensibilidad de arrastre: \(Int(appDelegate.dragThreshold)) px")
                        .font(.subheadline)
                    
                    // ¡AQUÍ ESTÁ EL CAMBIO FINAL! El rango ahora es de 20 a 1000.
                    Slider(value: $appDelegate.dragThreshold, in: 20...1000, step: 10) {
                        Text("Sensibilidad")
                    } minimumValueLabel: {
                        Text("Alta")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("Baja")
                            .font(.caption)
                    }
                }
                .padding(.top, 10)
            }
            
            Spacer()
            
            // --- Botones de Acción ---
            HStack {
                Button {
                    appDelegate.moveToMenuBar()
                } label: {
                    Label("Mover a la Barra de Menús", systemImage: "arrow.up.right.square")
                }
                
                Spacer()
                
                Button("Salir") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(30)
        .frame(width: 450, height: 480)
    }
}
