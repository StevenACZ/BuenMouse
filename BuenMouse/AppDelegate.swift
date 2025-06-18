// Archivo: AppDelegate.swift
// VERSIÓN COMPLETA, ESTABLE Y FIABLE (SIN OPTIMIZACIÓN DE VELOCIDAD)

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
    @Published var isMonitoringActive = false { didSet { if isMonitoringActive { startMonitoring() } else { stopMonitoring() } } }
    @Published var launchAtLogin = (SMAppService.mainApp.status == .enabled) { didSet { if launchAtLogin { ServiceManager.register() } else { ServiceManager.unregister() } } }
    @Published var invertDragDirection = false

    // MARK: - Variables Internas
    private var eventTap: CFMachPort?
    private var isMiddleMouseDown = false
    private var initialMouseLocation: CGPoint?
    private var isWaitingForMissionControlExit = false // Para la "cárcel" de Mission Control

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

    // MARK: - Lógica Principal del Event Tap (LÓGICA ESTABLE)
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        
        // --- Lógica para cuando ESTAMOS DENTRO de Mission Control ---
        if isWaitingForMissionControlExit {
            if type == .otherMouseDown {
                SystemActionRunner.activateMissionControl() // Llama de nuevo para salir
                isWaitingForMissionControlExit = false
                return nil // Consume el evento
            }
            return Unmanaged.passUnretained(event) // Ignora otros eventos
        }

        // --- Lógica para cuando NO ESTAMOS en Mission Control ---
        switch type {
        case .otherMouseDown:
            // Al presionar, solo guardamos el estado inicial. No hacemos ninguna acción.
            isMiddleMouseDown = true
            initialMouseLocation = event.location
            
        case .otherMouseUp:
            // Toda la lógica ocurre al soltar el botón.
            guard isMiddleMouseDown, let startLocation = initialMouseLocation else {
                isMiddleMouseDown = false
                return Unmanaged.passUnretained(event)
            }
            
            isMiddleMouseDown = false
            let endLocation = event.location
            let deltaX = endLocation.x - startLocation.x
            let distance = hypot(deltaX, endLocation.y - startLocation.y)
            
            let dragThreshold: CGFloat = 40.0 // Umbral para considerar un arrastre
            let clickThreshold: CGFloat = 10.0 // Umbral para considerar un clic
            
            if abs(deltaX) > dragThreshold {
                // Es un arrastre claro para cambiar de espacio.
                if deltaX > 0 { // Movimiento a la derecha
                    if invertDragDirection { SystemActionRunner.moveToPreviousSpace() } else { SystemActionRunner.moveToNextSpace() }
                } else { // Movimiento a la izquierda
                    if invertDragDirection { SystemActionRunner.moveToNextSpace() } else { SystemActionRunner.moveToPreviousSpace() }
                }
            } else if distance < clickThreshold {
                // Es un clic claro, el ratón apenas se movió.
                triggerMissionControlAction()
            }
            
            // Si el movimiento fue intermedio (ni un clic claro ni un arrastre claro), no hacemos nada.
            // Consumimos el evento para evitar efectos secundarios.
            return nil

        default:
            // Ignoramos otros eventos como .mouseMoved
            break
        }
        
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Funciones de Ayuda
    private func triggerMissionControlAction() {
        print("Acción de Mission Control disparada.")
        SystemActionRunner.activateMissionControl()
        isWaitingForMissionControlExit = true
    }

    // MARK: - Funciones de Monitoreo
    private func startMonitoring() {
        guard eventTap == nil else { return }
        // Solo escuchamos los eventos de presionar y soltar.
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
