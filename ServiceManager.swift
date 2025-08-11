import Foundation
import ServiceManagement

enum ServiceError: LocalizedError {
    case registrationFailed(String)
    case unregistrationFailed(String)
    case statusCheckFailed
    case alreadyRegistered
    case notRegistered
    
    var errorDescription: String? {
        switch self {
        case .registrationFailed(let message):
            return "No se pudo registrar el inicio automático: \(message)"
        case .unregistrationFailed(let message):
            return "No se pudo desregistrar el inicio automático: \(message)"
        case .statusCheckFailed:
            return "No se pudo verificar el estado del inicio automático"
        case .alreadyRegistered:
            return "El inicio automático ya está registrado"
        case .notRegistered:
            return "El inicio automático no está registrado"
        }
    }
}

enum ServiceManager {
    static func register() -> Result<Void, ServiceError> {
        do {
            let currentStatus = SMAppService.mainApp.status
            
            switch currentStatus {
            case .notRegistered:
                try SMAppService.mainApp.register()
                print("✅ Servicio de inicio registrado con éxito.")
                return .success(())
            case .enabled:
                print("ℹ️ Servicio ya está registrado y habilitado.")
                return .failure(.alreadyRegistered)
            case .requiresApproval:
                print("⚠️ Servicio requiere aprobación del usuario.")
                return .success(()) // Consider this a success, user needs to approve
            case .notFound:
                try SMAppService.mainApp.register()
                print("✅ Servicio registrado después de no encontrarse.")
                return .success(())
            @unknown default:
                print("⚠️ Estado desconocido del servicio: \(currentStatus)")
                try SMAppService.mainApp.register()
                return .success(())
            }
        } catch {
            print("❌ Error al registrar el servicio de inicio: \(error.localizedDescription)")
            return .failure(.registrationFailed(error.localizedDescription))
        }
    }

    static func unregister() -> Result<Void, ServiceError> {
        do {
            let currentStatus = SMAppService.mainApp.status
            
            switch currentStatus {
            case .enabled, .requiresApproval:
                try SMAppService.mainApp.unregister()
                print("✅ Servicio de inicio eliminado con éxito.")
                return .success(())
            case .notRegistered, .notFound:
                print("ℹ️ Servicio no está registrado.")
                return .failure(.notRegistered)
            @unknown default:
                print("⚠️ Estado desconocido del servicio: \(currentStatus)")
                try SMAppService.mainApp.unregister()
                return .success(())
            }
        } catch {
            print("❌ Error al eliminar el servicio de inicio: \(error.localizedDescription)")
            return .failure(.unregistrationFailed(error.localizedDescription))
        }
    }
    
    static var currentStatus: SMAppService.Status {
        return SMAppService.mainApp.status
    }
    
    static var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    static func syncWithUserDefaults() -> Bool {
        let userDefaultsValue = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let systemEnabled = isEnabled
        
        print("🔄 Sincronizando estado: UserDefaults=\(userDefaultsValue), Sistema=\(systemEnabled)")
        
        if userDefaultsValue != systemEnabled {
            print("⚠️ Estado desincronizado detectado")
            return false
        }
        
        return true
    }
}
