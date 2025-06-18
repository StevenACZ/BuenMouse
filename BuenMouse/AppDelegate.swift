// Archivo: AppDelegate.swift
// VERSIÓN COMPLETA Y FINAL CON SENSIBILIDAD CONFIGURABLE

import Cocoa
import ApplicationServices
import ServiceManagement

// --- Función C Global Segura (sin cambios) ---
private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let myself = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
    return myself.handleEvent(proxy: proxy, type: type, event: event)
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // MARK: - Variables de Estado (Publicadas para la UI)
    
    @Published var isMonitoringActive = false {
        didSet {
            if isMonitoringActive {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @Published var launchAtLogin = (SMAppService.mainApp.status == .enabled) {
        didSet {
            if launchAtLogin {
                ServiceManager.register()
            } else {
                ServiceManager.unregister()
            }
        }
    }
    
    @Published var invertDragDirection: Bool = UserDefaults.standard.bool(forKey: "invertDragDirection") {
        didSet {
            UserDefaults.standard.set(invertDragDirection, forKey: "invertDragDirection")
        }
    }

    // ¡NUEVA VARIABLE! La sensibilidad del arrastre, ahora configurable.
    // La cargamos desde UserDefaults al iniciar, con un valor por defecto de 40.0.
    @Published var dragThreshold: Double = UserDefaults.standard.double(forKey: "dragThreshold") == 0 ? 40.0 : UserDefaults.standard.double(forKey: "dragThreshold") {
        didSet {
            // Cada vez que el slider cambia, guardamos el nuevo valor.
            UserDefaults.standard.set(dragThreshold, forKey: "dragThreshold")
        }
    }

    // MARK: - Variables Internas
    
    private var eventTap: CFMachPort?
    private var isMiddleMouseDown = false
    private var initialMouseLocation: CGPoint?
    private var isWaitingForMissionControlExit = false

    // MARK: - Referencias a la UI
    
    var window: NSWindow?
    var statusItem: NSStatusItem?
    
    // MARK: - Ciclo de Vida de la App
    
    func applicationDidFinishLaunching(_ note: Notification) {
        requestPermissions()
        isMonitoringActive = true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Lógica Principal del Event Tap
    
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        
        if isWaitingForMissionControlExit {
            if type == .otherMouseDown {
                SystemActionRunner.activateMissionControl()
                isWaitingForMissionControlExit = false
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .otherMouseDown:
            isMiddleMouseDown = true
            initialMouseLocation = event.location
            
        case .otherMouseUp:
            guard isMiddleMouseDown, let startLocation = initialMouseLocation else {
                isMiddleMouseDown = false
                return Unmanaged.passUnretained(event)
            }
            
            isMiddleMouseDown = false
            let endLocation = event.location
            let deltaX = endLocation.x - startLocation.x
            let distance = hypot(deltaX, endLocation.y - startLocation.y)
            
            let clickThreshold: CGFloat = 10.0
            
            // Usamos la variable de la clase, que es configurable.
            if abs(deltaX) > CGFloat(dragThreshold) {
                if deltaX > 0 {
                    if invertDragDirection { SystemActionRunner.moveToPreviousSpace() } else { SystemActionRunner.moveToNextSpace() }
                } else {
                    if invertDragDirection { SystemActionRunner.moveToNextSpace() } else { SystemActionRunner.moveToPreviousSpace() }
                }
            } else if distance < clickThreshold {
                triggerMissionControlAction()
            }
            
            return nil

        default:
            break
        }
        
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Funciones de Ayuda
    
    private func triggerMissionControlAction() {
        SystemActionRunner.activateMissionControl()
        isWaitingForMissionControlExit = true
    }

    // MARK: - Funciones de Monitoreo
    
    private func startMonitoring() {
        guard eventTap == nil else { return }
        let eventsToMonitor: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)
            
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: eventsToMonitor, callback: eventTapCallback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("Monitor estable iniciado.")
        }
    }

    private func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
            print("Monitor detenido.")
        }
    }
    
    // MARK: - Gestión de UI
    
    func moveToMenuBar() {
        self.window = NSApplication.shared.windows.first
        self.window?.close()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.click.badge.clock", accessibilityDescription: "BuenMouse")
            button.action = #selector(showMainWindow)
            button.target = self
        }
    }
    
    @objc func showMainWindow() {
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        statusItem = nil
    }

    // MARK: - Permisos
    
    private func requestPermissions() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        if !AXIsProcessTrustedWithOptions(opts) { print("Permisos de accesibilidad no concedidos.") }
    }
}
