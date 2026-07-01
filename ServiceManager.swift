import Foundation
import ServiceManagement
import os.log

/// Thin wrapper around SMAppService for the launch-at-login toggle.
enum ServiceManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app as a login item. Returns the actual
    /// resulting state so callers can keep UI in sync with the system.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            os_log(
                "Launch at login change failed: %{public}@",
                log: .default, type: .error, error.localizedDescription)
        }
        return isEnabled
    }
}
