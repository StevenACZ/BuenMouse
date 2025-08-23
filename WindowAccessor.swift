import SwiftUI
import os.log

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        // Usar un approach más robusto para obtener la ventana
        DispatchQueue.main.async {
            if let foundWindow = view.window {
                self.window = foundWindow
                os_log("WindowAccessor: Window found and assigned", log: .default, type: .info)
            } else {
                // Intentar de nuevo después de un delay muy corto
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    if let foundWindow = view.window {
                        self.window = foundWindow
                        os_log("WindowAccessor: Window found on second attempt", log: .default, type: .info)
                    } else {
                        os_log("WindowAccessor: Window not found after delay", log: .default, type: .info)
                    }
                }
            }
        }
        
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Verificar si la ventana cambió y actualizar si es necesario
        if window != nsView.window {
            DispatchQueue.main.async {
                self.window = nsView.window
                if nsView.window != nil {
                    os_log("WindowAccessor: Window reference updated", log: .default, type: .info)
                }
            }
        }
    }
}
