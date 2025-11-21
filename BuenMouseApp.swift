import SwiftUI

@main
struct BuenMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(settings: appDelegate.settingsManager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 600)
    }
}
