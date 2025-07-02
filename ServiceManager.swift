import Foundation
import ServiceManagement

enum ServiceManager {
    static func register() {
        do {
            try SMAppService.mainApp.register()
            print("Servicio de inicio registrado con éxito.")
        } catch {
            print("Error al registrar el servicio de inicio: \(error.localizedDescription)")
        }
    }

    static func unregister() {
        do {
            try SMAppService.mainApp.unregister()
            print("Servicio de inicio eliminado con éxito.")
        } catch {
            print("Error al eliminar el servicio de inicio: \(error.localizedDescription)")
        }
    }
}
