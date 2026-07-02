import Foundation

nonisolated extension String {
    /// Returns the localized string using the global LocalizationManager.
    var localized: String {
        LocalizationManager.shared.localizedString(self)
    }

    /// Returns the localized string formatted with arguments.
    func localized(_ args: CVarArg...) -> String {
        LocalizationManager.shared.localizedString(self, arguments: args)
    }
}
