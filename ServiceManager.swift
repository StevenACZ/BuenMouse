import Foundation
import ServiceManagement

enum ServiceManager {
    static func register() {
        do {
            if SMAppService.mainApp.status == .notRegistered {
                try SMAppService.mainApp.register()
                print("✅ Servicio de inicio registrado con éxito.")
            } else {
                print("ℹ️ Servicio ya está registrado.")
            }
        } catch {
            print("❌ Error al registrar el servicio de inicio: \(error.localizedDescription)")
        }
    }

    static func unregister() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                print("✅ Servicio de inicio eliminado con éxito.")
            } else {
                print("ℹ️ Servicio no está registrado.")
            }
        } catch {
            print("❌ Error al eliminar el servicio de inicio: \(error.localizedDescription)")
        }
    }
    
    static var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }
}
