// Archivo: AppDelegate.swift
// VERSIÓN FINAL CON LÓGICA DE TEMPORIZADOR INTELIGENTE

import Cocoa
import ApplicationServices
import ServiceManagement

// --- Función C Global Segura ---
private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }
    let myself = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
    
    // Pasamos el evento a nuestra clase para que decida qué hacer.
    return myself.handleEvent(proxy: proxy, type: type, event: event)
}


final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // --- Variables de Estado ---
    @Published var isMonitoringActive = false {
        didSet {
            // Cada vez que este valor cambia, iniciamos o detenemos el monitoreo.
            if isMonitoringActive {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    @Published var launchAtLogin = (SMAppService.mainApp.status == .enabled) {
        didSet {
            // Cada vez que el toggle de la UI cambia, registramos o eliminamos el servicio.
            if launchAtLogin {
                ServiceManager.register()
            } else {
                ServiceManager.unregister()
            }
        }
    }

    private var eventTap: CFMachPort?
    private var isMiddleMouseDown = false
    private var initialMouseLocation: CGPoint?
    private var hasMovedToNextSpace = false
    
    // ¡NUEVA VARIABLE! El temporizador para diferenciar clic de arrastre.
    private var clickTimer: Timer?

    // --- Referencias a la UI ---
    var statusItem: NSStatusItem?
    var window: NSWindow?

    // --- Ciclo de Vida de la App ---
    func applicationDidFinishLaunching(_ note: Notification) {
        requestPermissions()
        // Activamos el monitoreo por defecto al iniciar la app.
        isMonitoringActive = true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // --- Lógica Principal del Event Tap ---
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .otherMouseDown:
            isMiddleMouseDown = true
            initialMouseLocation = event.location
            hasMovedToNextSpace = false
            
            clickTimer?.invalidate() // Cancelamos cualquier temporizador anterior.
            
            // Creamos un temporizador que se disparará en 0.15 segundos.
            // Si el ratón no se mueve en ese tiempo, se considera un clic.
            clickTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                
                print("El temporizador se completó. ¡Esto es un CLIC!")
                SystemActionRunner.activateMissionControl()
                
                // Anulamos el evento original de "mouse up" para que no haga nada más.
                // Para ello, deshabilitamos y rehabilitamos el tap momentáneamente.
                if let tap = self.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: false)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                }
            }
            
            return Unmanaged.passUnretained(event)
            
        case .otherMouseUp:
            // Si soltamos el botón ANTES de que el temporizador termine, también es un clic.
            if let timer = clickTimer, timer.isValid {
                print("Se soltó el botón rápidamente. ¡Esto es un CLIC!")
                timer.invalidate()
                SystemActionRunner.activateMissionControl()
                return nil // "Robamos" el evento para que no haga nada más (ej. cerrar pestaña).
            }
            isMiddleMouseDown = false
            initialMouseLocation = nil
            
        case .mouseMoved, .otherMouseDragged:
            guard isMiddleMouseDown, let startLocation = initialMouseLocation else {
                return Unmanaged.passUnretained(event)
            }
            
            let currentLocation = event.location
            let distance = hypot(currentLocation.x - startLocation.x, currentLocation.y - startLocation.y)
            
            // Si nos movemos una distancia mínima, cancelamos el temporizador. ¡No es un clic!
            if distance > 5.0 {
                clickTimer?.invalidate()
            }

            if !hasMovedToNextSpace {
                let deltaX = currentLocation.x - startLocation.x
                let threshold: CGFloat = 40.0 // Umbral de arrastre
                
                if deltaX > threshold {
                    SystemActionRunner.moveToNextSpace()
                    hasMovedToNextSpace = true
                    return nil
                } else if deltaX < -threshold {
                    SystemActionRunner.moveToPreviousSpace()
                    hasMovedToNextSpace = true
                    return nil
                }
            }
            
        default:
            break
        }
        
        return Unmanaged.passUnretained(event)
    }

    // --- Funciones de Inicio y Parada del Monitoreo ---
    private func startMonitoring() {
        guard eventTap == nil else { return }
        
        let eventsToMonitor: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: eventsToMonitor, callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("Monitor iniciado.")
        }
    }

    private func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap) // Liberamos el recurso
            eventTap = nil
            print("Monitor detenido.")
        }
    }
    
    // --- Gestión de la Ventana y Barra de Menús ---
    func moveToMenuBar() {
        self.window = NSApplication.shared.windows.first
        self.window?.close()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.click.badge.clock", accessibilityDescription: "BuenMouse")
            button.action = #selector(showMainWindow)
            button.target = self // ¡Importante! Especificar el target.
        }
    }
    
    @objc func showMainWindow() {
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        statusItem = nil
    }

    // --- Permisos ---
    private func requestPermissions() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        if !AXIsProcessTrustedWithOptions(opts) {
            print("AppDelegate: Permisos de accesibilidad no concedidos.")
        }
    }
}
