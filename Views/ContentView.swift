import SwiftUI

struct ContentView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. Settings
            SettingsView(settings: settings)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(0)

            // 2. Shortcuts / Help
            ShortcutsView(settings: settings)
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }
                .tag(1)

            // 3. About
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(2)
        }

        .padding(28)
        .frame(minWidth: 950, idealWidth: 1050, maxWidth: 1250, minHeight: 480, idealHeight: 540, maxHeight: 650)
    }
}

// --- Settings Page ---
struct SettingsView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings
    @State private var hoveredCard: String? = nil

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > 900
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header con gradiente
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Settings")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.primary, .primary.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            Text("Customize your BuenMouse experience")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        // Dark mode toggle
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Button(action: {
                                    settings.followSystemAppearance = !settings.followSystemAppearance
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: settings.followSystemAppearance ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(settings.followSystemAppearance ? .blue : .secondary)
                                        Text("Auto")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    if !settings.followSystemAppearance {
                                        settings.isDarkMode = !settings.isDarkMode
                                    }
                                }) {
                                    Image(systemName: settings.isDarkMode ? "moon.fill" : "sun.max.fill")
                                        .font(.title2)
                                        .foregroundColor(settings.followSystemAppearance ? .secondary : (settings.isDarkMode ? .indigo : .orange))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(settings.followSystemAppearance)
                            }
                        }
                        
                        // Icono decorativo
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.horizontal, 4)
                    
                    if isWide {
                        HStack(alignment: .top, spacing: 28) {
                            generalBox
                            mouseBox
                            scrollBox
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 28) {
                            generalBox
                            mouseBox
                            scrollBox
                        }
                    }
                    
                    // Botones modernos con efectos
                    actionButtonsSection
                }
                .padding(.vertical, 12)
                .padding(.horizontal, isWide ? 36 : 16)
            }
        }
    }

    private var generalBox: some View {
        ModernCard(
            title: "General Settings",
            icon: "gearshape.fill",
            gradientColors: [.blue, .cyan],
            isHovered: hoveredCard == "general"
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ModernToggle(
                    isOn: $settings.isMonitoringActive,
                    label: "Enable gesture monitoring",
                    icon: "hand.tap.fill",
                    description: "Activate mouse gesture recognition"
                )
                
                ModernToggle(
                    isOn: $settings.launchAtLogin,
                    label: "Launch at login",
                    icon: "arrow.triangle.2.circlepath",
                    description: "Start automatically with macOS"
                )
                
                ModernToggle(
                    isOn: $settings.startInMenubar,
                    label: "Start in menubar",
                    icon: "menubar.rectangle",
                    description: "Begin minimized in menu bar"
                )
            }
        }
        .onHover { isHovering in
            hoveredCard = isHovering ? "general" : nil
        }
    }

    private var mouseBox: some View {
        ModernCard(
            title: "Mouse & Drag",
            icon: "cursorarrow.motionlines.click",
            gradientColors: [.purple, .pink],
            isHovered: hoveredCard == "mouse"
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ModernToggle(
                    isOn: $settings.invertDragDirection,
                    label: "Invert drag direction",
                    icon: "arrow.left.and.right.circle",
                    description: "Reverse horizontal drag behavior"
                )
                .disabled(!settings.isMonitoringActive)
                .opacity(settings.isMonitoringActive ? 1.0 : 0.5)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "slider.horizontal.below.square.filled.and.square")
                            .foregroundStyle(.purple)
                        Text("Drag Sensitivity")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(settings.dragThreshold)) px")
                            .font(.system(.title3, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Slider(value: $settings.dragThreshold, in: 0...500, step: 5)
                        .tint(.purple)
                        .disabled(!settings.isMonitoringActive)
                }
            }
        }
        .disabled(!settings.isMonitoringActive)
        .opacity(settings.isMonitoringActive ? 1.0 : 0.5)
        .onHover { isHovering in
            hoveredCard = isHovering ? "mouse" : nil
        }
    }

    private var scrollBox: some View {
        ModernCard(
            title: "Scroll & Zoom",
            icon: "arrow.up.left.and.down.right.magnifyingglass",
            gradientColors: [.green, .mint],
            isHovered: hoveredCard == "scroll"
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ModernToggle(
                    isOn: $settings.enableScrollZoom,
                    label: "Enable Ctrl + Scroll zoom",
                    icon: "plus.magnifyingglass",
                    description: "Use Control + scroll wheel to zoom"
                )
                .disabled(!settings.isMonitoringActive)
                
                if settings.enableScrollZoom {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.green)
                        Text("Hold ⌃ Control and scroll to zoom in/out")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 8)
                }
                
                ModernToggle(
                    isOn: $settings.invertScroll,
                    label: "Invert global scroll",
                    icon: "arrow.up.arrow.down.circle",
                    description: "Reverse mouse scroll direction"
                )
                .disabled(!settings.isMonitoringActive)
                
                if settings.invertScroll {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.mint)
                        Text("Natural scrolling for mouse wheel")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 8)
                }
            }
        }
        .disabled(!settings.isMonitoringActive)
        .opacity(settings.isMonitoringActive ? 1.0 : 0.5)
        .onHover { isHovering in
            hoveredCard = isHovering ? "scroll" : nil
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 20) {
            ModernActionButton(
                title: "Move to Menubar",
                icon: "arrow.up.right.square",
                gradientColors: [.blue, .indigo],
                action: { settings.moveToMenuBar() }
            )
            
            Spacer()
            
            ModernActionButton(
                title: "Quit App",
                icon: "power",
                gradientColors: [.red, .orange],
                action: { NSApplication.shared.terminate(nil) }
            )
        }
        .padding(.top, 16)
        .padding(.horizontal, 4)
    }
}

// --- Shortcuts/Help Page ---
struct ShortcutsView<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings
    @State private var selectedShortcut: Int? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header elegante
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shortcuts & Help")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("Master your mouse gestures")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "command.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.horizontal, 4)
                
                // Shortcuts grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 20) {
                    ShortcutCard(
                        index: 0,
                        title: "Ctrl + Click & Drag",
                        description: "Scrolls content like trackpad two-finger gesture. Perfect for smooth navigation.",
                        icon: "hand.draw",
                        gradientColors: [.blue, .cyan],
                        isSelected: selectedShortcut == 0
                    )
                    .onTapGesture {
                        selectedShortcut = selectedShortcut == 0 ? nil : 0
                    }
                    
                    ShortcutCard(
                        index: 2,
                        title: "Middle Mouse + Drag",
                        description: "Switch between Spaces/Desktops. Drag horizontally for workspace switching.",
                        icon: "rectangle.3.offgrid",
                        gradientColors: [.green, .mint],
                        isSelected: selectedShortcut == 2
                    )
                    .onTapGesture {
                        selectedShortcut = selectedShortcut == 2 ? nil : 2
                    }
                    
                    ShortcutCard(
                        index: 3,
                        title: "Mouse Button 3 (Back)",
                        description: "Navigate back in browsers, Finder, and other apps. Quick navigation.",
                        icon: "arrow.left.circle",
                        gradientColors: [.orange, .yellow],
                        isSelected: selectedShortcut == 3
                    )
                    .onTapGesture {
                        selectedShortcut = selectedShortcut == 3 ? nil : 3
                    }
                    
                    ShortcutCard(
                        index: 4,
                        title: "Mouse Button 4 (Forward)",
                        description: "Navigate forward in browsers, Finder, and other apps. Complete workflow.",
                        icon: "arrow.right.circle",
                        gradientColors: [.red, .pink],
                        isSelected: selectedShortcut == 4
                    )
                    .onTapGesture {
                        selectedShortcut = selectedShortcut == 4 ? nil : 4
                    }
                    
                    if settings.enableScrollZoom {
                        ShortcutCard(
                            index: 1,
                            title: "Ctrl + Scroll",
                            description: "Zoom in/out with mouse wheel while holding Control. Great for detailed work.",
                            icon: "plus.magnifyingglass",
                            gradientColors: [.purple, .pink],
                            isSelected: selectedShortcut == 1
                        )
                        .onTapGesture {
                            selectedShortcut = selectedShortcut == 1 ? nil : 1
                        }
                    }
                }
            }
            .padding(36)
        }
    }
}

// --- About Page ---
struct AboutView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            // Logo y header con animación
            HStack(spacing: 24) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("BuenMouse")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("Your productivity assistant")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Línea decorativa
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.clear, .blue, .purple, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Información del desarrollador
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                    Text("Created by Steven Coaila Zaa")
                        .font(.title2.bold())
                }
                
                Text("BuenMouse is a lightweight, powerful utility for macOS designed to boost your productivity and give you full control over your mouse gestures. I hope it helps you as much as it helped me!")
                    .font(.title3)
                    .lineSpacing(4)
            }
            
            // Features destacadas en grid de 2 columnas
            VStack(alignment: .leading, spacing: 16) {
                Text("Key Features")
                    .font(.title2.bold())
                    .padding(.bottom, 8)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ], spacing: 16) {
                    FeatureRow(icon: "hand.tap.fill", title: "Gesture Recognition", description: "Advanced mouse gesture detection")
                    FeatureRow(icon: "gearshape.2.fill", title: "Customizable", description: "Tailor every setting to your needs")
                    FeatureRow(icon: "bolt.fill", title: "Lightweight", description: "Minimal system resource usage")
                    FeatureRow(icon: "lock.shield.fill", title: "Privacy First", description: "All processing happens locally")
                }
            }
            
            Spacer()
        }
        .padding(36)
    }
}

// MARK: - Componentes Modernos

struct ModernCard<Content: View>: View {
    let title: String
    let icon: String
    let gradientColors: [Color]
    let isHovered: Bool
    let content: Content
    
    init(title: String, icon: String, gradientColors: [Color], isHovered: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.gradientColors = gradientColors
        self.isHovered = isHovered
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header de la card
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(title)
                    .font(.title3.bold())
                Spacer()
            }
            
            content
        }
        .padding(24)
        .background(.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: isHovered ? gradientColors : [.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHovered ? 1 : 0
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .frame(maxWidth: .infinity)
    }
}

struct ModernToggle: View {
    @Binding var isOn: Bool
    let label: String
    let icon: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isOn) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundColor(isOn ? .blue : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.headline)
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
    }
}

struct ModernActionButton: View {
    let title: String
    let icon: String
    let gradientColors: [Color]
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.headline.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12)
            )

        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct ShortcutCard: View {
    let index: Int
    let title: String
    let description: String
    let icon: String
    let gradientColors: [Color]
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if isSelected {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(minHeight: isSelected ? 120 : 80)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: isSelected ? gradientColors : [.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 1 : 0
                )
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}