import Cocoa
import ApplicationServices
import ServiceManagement
import Combine
import os

private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let myself = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
    return myself.handleEvent(proxy: proxy, type: type, event: event)
}

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, SettingsProtocol {

    @Published var isMonitoringActive = false {
        didSet { isMonitoringActive ? startMonitoring() : stopMonitoring() }
    }

    @Published var launchAtLogin = (SMAppService.mainApp.status == .enabled) {
        didSet { launchAtLogin ? ServiceManager.register() : ServiceManager.unregister() }
    }

    @Published var invertDragDirection = UserDefaults.standard.bool(forKey: "invertDragDirection") {
        didSet { UserDefaults.standard.set(invertDragDirection, forKey: "invertDragDirection") }
    }

    @Published var dragThreshold: Double = UserDefaults.standard.double(forKey: "dragThreshold") == 0 ? 40.0 : UserDefaults.standard.double(forKey: "dragThreshold") {
        didSet { UserDefaults.standard.set(dragThreshold, forKey: "dragThreshold") }
    }
    
    @Published var startInMenubar = UserDefaults.standard.bool(forKey: "startInMenubar") {
        didSet { UserDefaults.standard.set(startInMenubar, forKey: "startInMenubar") }
    }

    private enum GestureState {
        case idle
        case tracking(startLocation: CGPoint)
        case dragging(startLocation: CGPoint)
        case inMissionControl
    }
    private var currentState: GestureState = .idle
    private var eventTap: CFMachPort?
    private var dragTimer: DispatchSourceTimer?
    private var cancellables = Set<AnyCancellable>()
    
    var window: NSWindow?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ note: Notification) {
        requestPermissions()
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in self?.spaceDidChange() }
            .store(in: &cancellables)

        isMonitoringActive = true

        DispatchQueue.main.async { [weak self] in
            if let window = self?.window ?? NSApplication.shared.windows.first {
                window.setContentSize(NSSize(width: 400, height: 440))
                window.center()
                window.styleMask.remove(.resizable)
            }
        }

        if startInMenubar {
            moveToMenuBar()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func spaceDidChange() {
        if isMonitoringActive { restartMonitoring() }
        if case .inMissionControl = currentState { currentState = .idle }
    }

    private func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }

    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        guard buttonNumber == 2 else { return Unmanaged.passUnretained(event) }

        switch currentState {
        case .idle:
            if type == .otherMouseDown {
                scheduleDragTimer()
                currentState = .tracking(startLocation: event.location)
            }
        case .tracking(let startLocation):
            if type == .otherMouseUp {
                cancelDragTimer()
                triggerMissionControlAction()
                return nil
            }
            if type == .mouseMoved || type == .otherMouseDragged {
                if hypot(event.location.x - startLocation.x, event.location.y - startLocation.y) > 8.0 {
                    cancelDragTimer()
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
                        invertDragDirection ? SystemActionRunner.moveToPreviousSpace() : SystemActionRunner.moveToNextSpace()
                    } else {
                        invertDragDirection ? SystemActionRunner.moveToNextSpace() : SystemActionRunner.moveToPreviousSpace()
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

    private func triggerMissionControlAction() {
        if case .inMissionControl = currentState { return }
        SystemActionRunner.activateMissionControl()
        currentState = .inMissionControl
    }

    private func scheduleDragTimer() {
        dragTimer = DispatchSource.makeTimerSource(queue: .main)
        dragTimer?.schedule(deadline: .now() + 0.2)
        dragTimer?.setEventHandler { [weak self] in
            self?.triggerMissionControlAction()
        }
        dragTimer?.resume()
    }

    private func cancelDragTimer() {
        dragTimer?.cancel()
        dragTimer = nil
    }

    private func startMonitoring() {
        guard eventTap == nil else { return }
        let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue) |
                                (1 << CGEventType.otherMouseUp.rawValue) |
                                (1 << CGEventType.mouseMoved.rawValue) |
                                (1 << CGEventType.otherMouseDragged.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        if let tap = eventTap {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
            currentState = .idle
        }
    }

    func moveToMenuBar() {
        window?.close()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.click.badge.clock", accessibilityDescription: "BuenMouse")
            button.action = #selector(showMainWindow)
            button.target = self
            button.setAccessibilityLabel("Icono de BuenMouse")
            button.setAccessibilityHelp("Haz clic para abrir la ventana principal")
        }
    }

    @objc func showMainWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        statusItem = nil
    }

    private func requestPermissions() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        if !AXIsProcessTrustedWithOptions(opts) {
            print("Permisos de accesibilidad no concedidos.")
        }
    }
}
