import SwiftUI

@main
struct BuenMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var mainWindow: NSWindow?

    var body: some Scene {
        WindowGroup {
            ContentView(settings: appDelegate)
                .background(WindowAccessor(window: $mainWindow))
                .onChange(of: mainWindow) {
                    if let win = mainWindow {
                        appDelegate.window = win
                    }
                }
        }
    }
}
