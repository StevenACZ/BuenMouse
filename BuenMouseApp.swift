import SwiftUI

@main
struct BuenMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var window: NSWindow?

    var body: some Scene {
        WindowGroup {
            ContentView(settings: appDelegate.settingsManager)
                .background(WindowAccessor(window: $window))
                .onChange(of: window) { _, newWindow in
                    appDelegate.setMainWindow(newWindow)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 600)
    }
}
