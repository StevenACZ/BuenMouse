// Archivo: AppDelegate.swift
// VERSIÓN FINAL RESILIENTE CON RECREACIÓN AUTOMÁTICA DEL EVENT TAP

import Cocoa
import ApplicationServices
import ServiceManagement

// --- Función C Global Segura para el Event Tap ---
private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let myself = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
    return myself.handleEvent(proxy: proxy, type: type, event: event)
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // MARK: - Variables de Estado (Publicadas para la UI)
    
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
            if launchAtLogin {
                ServiceManager.register()
            } else {
                ServiceManager.unregister()
            }
        }
    }
    
    @Published var invertDragDirection = false
    
    @Published var dragThreshold: Double = UserDefaults.standard.double(forKey: "dragThreshold") == 0 ? 40.0 : UserDefaults.standard.double(forKey: "dragThreshold") {
        didSet {
            UserDefaults.standard.set(dragThreshold, forKey: "dragThreshold")
        }
    }

    // MARK: - Máquina de Estados del Gesto
    
    private enum GestureState {
        case idle // Esperando una acción
        case tracking(startLocation: CGPoint, timer: Timer) // Botón presionado, decidiendo si es clic o arrastre
        case dragging(startLocation: CGPoint) // Gesto confirmado como arrastre
        case inMissionControl // Mission Control está activo en pantalla
    }
    private var currentState: GestureState = .idle
    private var eventTap: CFMachPort?
    
    // MARK: - Referencias a la UI
    
    var window: NSWindow?
    var statusItem: NSStatusItem?
    
    // MARK: - Ciclo de Vida de la App
    
    func applicationDidFinishLaunching(_ note: Notification) {
        requestPermissions()
        
        // Nos suscribimos a la notificación de cambio de espacio.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        
        // Activamos el monitoreo por defecto al iniciar la app.
        isMonitoringActive = true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Lógica de Resiliencia
    
    // Esta función se llama automáticamente cuando salimos de Mission Control o cambiamos de escritorio.
    @objc func spaceDidChange() {
        print("Cambio de espacio detectado. Asegurando que el monitor esté activo.")
        
        // Si el monitoreo debería estar activo, lo reiniciamos para asegurar que no se invalidó.
        if isMonitoringActive {
            // Reiniciar es tan simple como detener y volver a iniciar.
            stopMonitoring()
            startMonitoring()
        }
        
        // También reseteamos el estado de Mission Control por si acaso.
        if case .inMissionControl = currentState {
            currentState = .idle
        }
    }
    
    // MARK: - Lógica Principal del Event Tap (Máquina de Estados)
    
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        guard buttonNumber == 2 else { return Unmanaged.passUnretained(event) }

        switch currentState {
        case .idle:
            if type == .otherMouseDown {
                let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in self?.triggerMissionControlAction() }
                currentState = .tracking(startLocation: event.location, timer: timer)
            }
        case .tracking(let startLocation, let timer):
            if type == .otherMouseUp {
                timer.invalidate()
                triggerMissionControlAction()
                return nil
            }
            if type == .mouseMoved || type == .otherMouseDragged {
                if hypot(event.location.x - startLocation.x, event.location.y - startLocation.y) > 8.0 {
                    timer.invalidate()
                    currentState = .dragging(startLocation: startLocation)
                }
            }
        case .dragging(let startLocation):
            if type == .otherMouseUp {
                currentState = .idle
                return nil
            }
            if type == .mouseMoved || type == .otherMouseDragged {
                let deltaX = event.location.x - startLocation.x
                if abs(deltaX) > CGFloat(dragThreshold) {
                    if deltaX > 0 {
                        if invertDragDirection { SystemActionRunner.moveToPreviousSpace() } else { SystemActionRunner.moveToNextSpace() }
                    } else {
                        if invertDragDirection { SystemActionRunner.moveToNextSpace() } else { SystemActionRunner.moveToPreviousSpace() }
                    }
                    currentState = .idle
                    return nil
                }
            }
        case .inMissionControl:
            if type == .otherMouseDown {
                SystemActionRunner.activateMissionControl()
                currentState = .idle
                return nil
            }
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Funciones de Ayuda
    
    private func triggerMissionControlAction() {
        if case .inMissionControl = currentState { return }
        SystemActionRunner.activateMissionControl()
        currentState = .inMissionControl
    }

    // MARK: - Funciones de Monitoreo
    
    private func startMonitoring() {
        guard eventTap == nil else { return }
        let eventsToMonitor: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue) | (1 << CGEventType.mouseMoved.rawValue) | (1 << CGEventType.otherMouseDragged.rawValue)
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: eventsToMonitor, callback: eventTapCallback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("Monitor (Máquina de Estados) iniciado.")
        }
    }

    private func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
            currentState = .idle
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
