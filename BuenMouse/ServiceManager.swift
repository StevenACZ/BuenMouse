// Archivo: ServiceManager.swift
// VERSIÓN CON SINTAXIS CORREGIDA

import Foundation
import ServiceManagement

enum ServiceManager {
    static func register() {
        do {
            // La sintaxis correcta es .mainApp
            try SMAppService.mainApp.register()
            print("Servicio de inicio registrado con éxito.")
        } catch {
            print("Error al registrar el servicio de inicio: \(error.localizedDescription)")
        }
    }
    
    static func unregister() {
        do {
            // La sintaxis correcta es .mainApp
            try SMAppService.mainApp.unregister()
            print("Servicio de inicio eliminado con éxito.")
        } catch {
            print("Error al eliminar el servicio de inicio: \(error.localizedDescription)")
        }
    }
}
