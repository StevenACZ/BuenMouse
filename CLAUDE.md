# BuenMouse - Technical Documentation

## Project Overview
macOS productivity application that enhances mouse/trackpad functionality through system-level event interception and gesture recognition. Built with Swift/SwiftUI, operates as menu bar-only app with optimized performance.

## Core Architecture

### Event Processing Pipeline
```
CGEventTap → EventMonitor → GestureHandler/ScrollHandler → SystemActionRunner → macOS APIs
```

1. **CGEventTap**: Low-level event capture at system level
2. **EventMonitor**: Event filtering and delegation
3. **Handlers**: State-based gesture recognition
4. **SystemActionRunner**: Action execution via CGEvent/AppleScript

### Component Details

#### EventMonitor (Core/EventHandling/EventMonitor.swift)
- **Purpose**: Central event tap management and delegation
- **Event Mask**: Mouse buttons, drags, scroll wheel events
- **Performance**: Early filtering with `switch` statements for efficiency
- **Permissions**: Requests accessibility permissions via `AXIsProcessTrusted()`
- **Thread Safety**: Runs on main run loop with `CFRunLoopAddSource`

#### GestureHandler (Core/EventHandling/GestureHandler.swift)
- **State Machine**: `.idle`, `.tracking`, `.scrollingDrag`
- **Button Tracking**: Robust state tracking for mouse buttons 3/4 with debouncing
- **Timing Constants**:
  - `debounceInterval: 0.1s` - Minimum time between valid events
  - `eventClusterThreshold: 0.05s` - Duplicate event filtering
  - `maxClickDuration: 1.0s` - Maximum valid click duration
- **Gesture Types**:
  - Control+Click drag → scroll simulation
  - Right-click drag → space switching (threshold-based)
  - Button 3/4 → back/forward navigation

#### ScrollHandler (Core/EventHandling/ScrollHandler.swift)
- **Trackpad Detection**: Uses `scrollPhase` and `momentumPhase` fields
- **Scroll Inversion**: Modifies `deltaAxis1/deltaAxis2` values
- **Zoom Accumulation**: Prevents micro-scroll zoom triggers
- **Control+Scroll Zoom**: Disabled during active control-click scrolling

#### SystemActionRunner (Core/SystemActions/SystemActionRunner.swift)
- **AppleScript Integration**: Space navigation via System Events
- **CGEvent Generation**: Back/forward navigation, zoom controls
- **Virtual Key Codes**:
  - 123/124: Left/Right arrows for spaces
  - 24/27: +/- keys for zoom
- **Async Execution**: AppleScript runs on background queue

### Settings Architecture

#### SettingsManager (Core/Settings/SettingsManager.swift)
- **UserDefaults Integration**: Automatic persistence with `@Published` properties
- **Service Management**: Launch-at-login via `ServiceManager`
- **Appearance Control**: Dark mode and system appearance following
- **Real-time Updates**: Settings changes immediately affect handlers

#### Configuration Properties
```swift
@Published var isMonitoringActive: Bool  // Global enable/disable
@Published var launchAtLogin: Bool       // Login item registration
@Published var invertDragDirection: Bool // Space navigation direction
@Published var dragThreshold: Double    // Gesture sensitivity (default: 40px)
@Published var invertScroll: Bool       // Mouse scroll inversion
@Published var enableScrollZoom: Bool   // Control+scroll zoom
```

### System Integration

#### Permissions & Entitlements
- **Accessibility**: Required for CGEventTap
- **Apple Events**: Required for System Events control
- **Sandboxing**: None (uses direct system APIs)

#### App Configuration
- **LSUIElement**: `true` - Hides from dock
- **Status Bar**: NSStatusItem with system cursor icon
- **Window Management**: SwiftUI window shown/hidden from status bar

### Performance Optimizations

#### Event Handling
- **Early Returns**: Filter irrelevant events before processing
- **State Minimization**: Only track necessary gesture states
- **Memory Management**: Weak references prevent retain cycles
- **Thread Efficiency**: Main thread for UI, background for AppleScript

#### UI Optimizations
- **Zero Animations**: All SwiftUI animations disabled
- **Minimal Redraws**: @Published properties only for actual changes
- **Lazy Loading**: Components initialized only when needed

### Development Information

#### Project Structure
```
BuenMouse/
├── BuenMouseApp.swift          # SwiftUI App entry point
├── AppDelegate.swift           # NSApplication lifecycle, status bar
├── ServiceManager.swift        # Launch-at-login management
├── WindowAccessor.swift        # Window reference binding
├── Core/
│   ├── EventHandling/          # Event system components
│   ├── Settings/               # Configuration management
│   └── SystemActions/          # System interaction layer
├── Views/
│   └── ContentView.swift       # Main settings interface
└── Resources/                  # Assets, entitlements, Info.plist
```

#### Key Files for Common Tasks
- **Add new gesture**: `GestureHandler.swift` + `SystemActionRunner.swift`
- **Add new setting**: `SettingsManager.swift` + `ContentView.swift`
- **Modify event filtering**: `EventMonitor.swift`
- **Change system actions**: `SystemActionRunner.swift`

#### Build Configuration
- **Target**: macOS 13.0+
- **Architecture**: Universal (x86_64 + arm64)
- **Code Signing**: Developer ID required for distribution
- **Hardened Runtime**: Required for Gatekeeper

#### Debug Features
- **Event Logging**: Available in DEBUG builds
- **State Monitoring**: Button state tracking with console output
- **Performance Profiling**: OSLog integration for AppleScript timing

### Common Implementation Patterns

#### Adding New Gestures
1. Define state in `GestureHandler.swift`
2. Add detection logic in `handleEvent()`
3. Create system action in `SystemActionRunner.swift`
4. Add configuration option in `SettingsManager.swift`

#### Adding New Settings
1. Add `@Published` property with UserDefaults persistence
2. Update UI in `ContentView.swift`
3. Connect to relevant handler via weak reference

#### System Action Implementation
- Use CGEvent for key simulation (faster)
- Use AppleScript for complex system integration
- Always run AppleScript on background queue
- Implement error handling and logging