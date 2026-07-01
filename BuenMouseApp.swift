import SwiftUI

@main
struct BuenMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Status-bar-first app: every real window is created and owned by the
        // AppDelegate. An empty Settings scene keeps SwiftUI from opening any
        // window at launch (a WindowGroup here used to flash on every open).
        Settings {
            EmptyView()
        }
    }
}
