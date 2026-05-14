import SwiftUI

// MARK: - Gesture Types

enum GesturePreviewType: CaseIterable {
    case missionControl
    case spaceNavigation
    case scrollZoom
    case invertScroll

    var title: String {
        switch self {
        case .missionControl:  return "Middle Click → Mission Control"
        case .spaceNavigation: return "Middle Drag → Switch Spaces"
        case .scrollZoom:      return "⌃ + Scroll → Zoom In / Out"
        case .invertScroll:    return "Invert Scroll → Natural Direction"
        }
    }

    var subtitle: String {
        switch self {
        case .missionControl:  return "Press the scroll wheel to open Mission Control"
        case .spaceNavigation: return "Hold the scroll wheel and drag horizontally"
        case .scrollZoom:      return "Hold Control and use the scroll wheel"
        case .invertScroll:    return "Reverse the mouse wheel scroll direction"
        }
    }

    var accent: Color {
        switch self {
        case .missionControl:  return .purple
        case .spaceNavigation: return .blue
        case .scrollZoom:      return .green
        case .invertScroll:    return .green
        }
    }
}

// MARK: - Gesture Showcase

/// Auto-rotating carousel that demonstrates each gesture one at a time.
/// Placed once at the top of ContentView so toggles below stay clean.
struct GestureShowcase<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings

    private let items = GesturePreviewType.allCases
    private let autoAdvanceSeconds: TimeInterval = 4.5
    private let pauseAfterInteraction: TimeInterval = 30

    @State private var index: Int = 0
    @State private var autoTimer: Timer? = nil
    @State private var resumeTimer: Timer? = nil
    @State private var cardPressed: Bool = false

    private var current: GesturePreviewType { items[index] }

    /// Binds the current slide to the matching settings property.
    private var currentBinding: Binding<Bool> {
        switch current {
        case .missionControl:  return $settings.enableMissionControl
        case .spaceNavigation: return $settings.enableSpaceNavigation
        case .scrollZoom:      return $settings.enableScrollZoom
        case .invertScroll:    return $settings.invertScroll
        }
    }

    private var canToggle: Bool { settings.isMonitoringActive }
    private var isCurrentOn: Bool { canToggle && currentBinding.wrappedValue }

    private func isEnabled(_ type: GesturePreviewType) -> Bool {
        guard settings.isMonitoringActive else { return false }
        switch type {
        case .missionControl:  return settings.enableMissionControl
        case .spaceNavigation: return settings.enableSpaceNavigation
        case .scrollZoom:      return settings.enableScrollZoom
        case .invertScroll:    return settings.invertScroll
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(current.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                Text(current.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
            }
            .animation(.easeInOut(duration: 0.35), value: index)

            ZStack(alignment: .topTrailing) {
                ZStack {
                    ForEach(Array(items.enumerated()), id: \.offset) { offset, type in
                        GesturePreviewCard(type: type, isActive: isEnabled(type))
                            .opacity(offset == index ? 1 : 0)
                            .scaleEffect(offset == index ? 1 : 0.97)
                    }
                }
                .frame(height: 96)
                .animation(.easeInOut(duration: 0.4), value: index)

                statusBadge
                    .padding(10)
                    .animation(.easeInOut(duration: 0.25), value: isCurrentOn)
                    .animation(.easeInOut(duration: 0.35), value: index)
            }
            .scaleEffect(cardPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: cardPressed)
            .contentShape(Rectangle())
            .onTapGesture { handleCardTap() }
            .help(canToggle
                  ? "Tap to \(isCurrentOn ? "disable" : "enable") this gesture"
                  : "Turn on Gesture Monitoring to enable")

            // No inline toggles — the On/Off badge plus card-tap handle activation.
            // Space Navigation's extras (slider + invert drag) appear only when ON.
            if current == .spaceNavigation && settings.enableSpaceNavigation {
                spaceNavExtras
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97, anchor: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }

            HStack(spacing: 14) {
                navButton(systemName: "chevron.left") { step(-1) }

                HStack(spacing: 8) {
                    ForEach(items.indices, id: \.self) { i in
                        Capsule(style: .continuous)
                            .fill(i == index ? current.accent : Color.secondary.opacity(0.25))
                            .frame(width: i == index ? 18 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: index)
                            .contentShape(Rectangle())
                            .onTapGesture { selectManually(i) }
                    }
                }

                navButton(systemName: "chevron.right") { step(1) }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.3), value: settings.enableSpaceNavigation)
        .animation(.easeInOut(duration: 0.3), value: current)
        .onAppear { startAutoTimer() }
        .onDisappear { stopAllTimers() }
    }


    @ViewBuilder
    private var spaceNavExtras: some View {
        let extrasDisabled = !canToggle || !settings.enableSpaceNavigation
        VStack(spacing: 10) {
            HStack {
                Text("Drag distance to switch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(settings.dragThreshold)) px")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(extrasDisabled ? .secondary : .primary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: settings.dragThreshold)
            }

            Slider(
                value: $settings.dragThreshold,
                in: 0...400,
                step: 100,
                onEditingChanged: { editing in
                    if editing { pauseAndScheduleResume() }
                }
            )
            .tint(current.accent)
            .disabled(extrasDisabled)

            GeometryReader { geo in
                // Native SwiftUI macOS Slider has ~8pt thumb inset on each side,
                // so position labels against the actual thumb travel range.
                let inset: CGFloat = 8
                let trackWidth = max(0, geo.size.width - 2 * inset)
                ForEach([0, 100, 200, 300, 400], id: \.self) { tick in
                    let frac = CGFloat(tick) / 400
                    tickLabel(tick)
                        .fixedSize()
                        .position(x: inset + trackWidth * frac, y: 8)
                }
            }
            .frame(height: 16)
            .animation(.easeInOut(duration: 0.2), value: settings.dragThreshold)

            Toggle("Invert Drag Direction", isOn: Binding(
                get: { settings.invertDragDirection },
                set: { newValue in
                    settings.invertDragDirection = newValue
                    pauseAndScheduleResume()
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.top, 4)
            .disabled(extrasDisabled)
        }
        .padding(.horizontal, 4)
    }

    private var statusBadge: some View {
        let on = isCurrentOn
        return HStack(spacing: 5) {
            Circle()
                .fill(on ? current.accent : Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(on ? "On" : "Off")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(on ? current.accent : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(on ? current.accent.opacity(0.15) : Color.secondary.opacity(0.12))
        )
    }

    private func tickLabel(_ tick: Int) -> some View {
        let isActive = Int(settings.dragThreshold) == tick
        return Text("\(tick)")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(isActive ? AnyShapeStyle(current.accent) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
            .fontWeight(isActive ? .semibold : .regular)
    }

    private func handleCardTap() {
        guard canToggle else {
            pauseAndScheduleResume()
            return
        }
        cardPressed = true
        currentBinding.wrappedValue.toggle()
        pauseAndScheduleResume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            cardPressed = false
        }
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(Color.secondary.opacity(0.10))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer logic

    private func startAutoTimer() {
        stopAutoTimer()
        autoTimer = Timer.scheduledTimer(withTimeInterval: autoAdvanceSeconds, repeats: true) { _ in
            index = (index + 1) % items.count
        }
    }

    private func stopAutoTimer() {
        autoTimer?.invalidate()
        autoTimer = nil
    }

    private func stopAllTimers() {
        stopAutoTimer()
        resumeTimer?.invalidate()
        resumeTimer = nil
    }

    /// Called whenever the user interacts. Pauses auto-rotation and schedules
    /// a one-shot timer that resumes auto-rotation after `pauseAfterInteraction`s
    /// of inactivity. Re-interacting resets that countdown.
    private func pauseAndScheduleResume() {
        stopAutoTimer()
        resumeTimer?.invalidate()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: pauseAfterInteraction, repeats: false) { _ in
            startAutoTimer()
        }
    }

    private func step(_ direction: Int) {
        index = (index + direction + items.count) % items.count
        pauseAndScheduleResume()
    }

    private func selectManually(_ i: Int) {
        index = i
        pauseAndScheduleResume()
    }
}

// MARK: - Single preview card (animated illustration)

struct GesturePreviewCard: View {
    let type: GesturePreviewType
    var isActive: Bool = true

    @State private var phase: Double = 0
    @State private var directionToggle: Bool = false
    @State private var rippleProgress: CGFloat = 0
    @State private var holdClickPulse: CGFloat = 0
    @State private var phaseTimer: Timer? = nil
    @State private var directionTimer: Timer? = nil

    private let phaseInterval: TimeInterval = 1.4
    private let directionInterval: TimeInterval = 1.6

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill((isActive ? type.accent : Color.gray).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder((isActive ? type.accent : Color.gray).opacity(0.20), lineWidth: 1)
                )

            content
                .padding(.vertical, 12)
                .grayscale(isActive ? 0 : 1)
                .saturation(isActive ? 1 : 0)
                .opacity(isActive ? 1 : 0.55)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.35), value: isActive)
        .onAppear { startAnimating() }
        .onDisappear { stopAnimating() }
    }

    private func startAnimating() {
        stopAnimating()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: phaseInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: phaseInterval)) {
                phase = phase < 0.5 ? 1.0 : 0.0
            }
        }
        // Kick off the first oscillation immediately, then schedule the rest.
        runDirectionStep()
        directionTimer = Timer.scheduledTimer(withTimeInterval: directionInterval, repeats: true) { _ in
            runDirectionStep()
        }
    }

    /// Flip the mouse's direction and schedule a click pulse for the moment it
    /// crosses the center, so the wave only fires while at the midpoint.
    private func runDirectionStep() {
        withAnimation(.easeInOut(duration: directionInterval)) {
            directionToggle.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + directionInterval / 2) {
            fireCenterClick()
        }
    }

    /// Pulse the dot and emit a ripple — invoked only when the mouse is at center.
    private func fireCenterClick() {
        // Ripple: reset to 0 without animation, then expand + fade.
        var snap = Transaction(animation: nil)
        snap.disablesAnimations = true
        withTransaction(snap) { rippleProgress = 0 }
        withAnimation(.easeOut(duration: 0.95)) {
            rippleProgress = 1
        }
        // Dot pulse: quick squish-in, soft return.
        withAnimation(.easeOut(duration: 0.16)) {
            holdClickPulse = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeInOut(duration: 0.4)) {
                holdClickPulse = 0
            }
        }
    }

    private func stopAnimating() {
        phaseTimer?.invalidate(); phaseTimer = nil
        directionTimer?.invalidate(); directionTimer = nil
    }

    @ViewBuilder
    private var content: some View {
        switch type {
        case .missionControl:  missionControl
        case .spaceNavigation: spaceNavigation
        case .scrollZoom:      scrollZoom
        case .invertScroll:    invertScroll
        }
    }

    // MARK: Shared mouse glyph

    private var mouse: some View {
        Image(systemName: "computermouse.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 34, height: 50)
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.hierarchical)
    }

    private var mouseWithClick: some View {
        ZStack(alignment: .top) {
            mouse
            Circle()
                .fill(type.accent)
                .frame(width: 9, height: 9)
                .scaleEffect(1.0 + 0.5 * phase)
                .opacity(0.85 - 0.25 * phase)
                .offset(y: -4)
        }
    }

    private var mouseWithHold: some View {
        ZStack(alignment: .top) {
            mouse
            ZStack {
                // Outer wave — only emitted when the mouse passes through center.
                Circle()
                    .stroke(type.accent, lineWidth: 1.4)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1 + 2.5 * rippleProgress)
                    .opacity(Double(1 - rippleProgress))
                // The held-click dot. Steady most of the time, with a small
                // squish at center to convey the "click" landing.
                Circle()
                    .fill(type.accent)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.0 + 0.55 * holdClickPulse)
                    .opacity(0.85)
            }
            .offset(y: 12)
        }
    }

    // MARK: Variants

    private var missionControl: some View {
        HStack(spacing: 22) {
            mouseWithClick
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(type.accent.opacity(0.7))
            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 30))
                .foregroundStyle(type.accent)
        }
    }

    private var spaceNavigation: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(type.accent)
                .opacity(directionToggle ? 1 : 0.25)
                .scaleEffect(directionToggle ? 1.15 : 0.9)
                .offset(x: directionToggle ? -4 : 2)
            mouseWithHold
                .offset(x: directionToggle ? -16 : 16)
                .rotationEffect(.degrees(directionToggle ? -4 : 4))
            Image(systemName: "arrow.right")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(type.accent)
                .opacity(directionToggle ? 0.25 : 1)
                .scaleEffect(directionToggle ? 0.9 : 1.15)
                .offset(x: directionToggle ? -2 : 4)
        }
    }

    private var scrollZoom: some View {
        HStack(spacing: 12) {
            keyCap("⌃")
            Text("+")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            ZStack(alignment: .top) {
                mouse
                VStack(spacing: 2) {
                    Image(systemName: "chevron.up")
                        .opacity(directionToggle ? 1 : 0.3)
                        .scaleEffect(directionToggle ? 1.1 : 0.9)
                    Image(systemName: "chevron.down")
                        .opacity(directionToggle ? 0.3 : 1)
                        .scaleEffect(directionToggle ? 0.9 : 1.1)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(type.accent)
                .offset(y: -10)
                .animation(.easeInOut(duration: 2.2), value: directionToggle)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(type.accent.opacity(0.7))
            Image(systemName: directionToggle ? "plus.magnifyingglass" : "minus.magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(type.accent)
                .animation(.easeInOut(duration: 2.2), value: directionToggle)
        }
    }

    private var invertScroll: some View {
        HStack(spacing: 22) {
            ZStack(alignment: .top) {
                mouse
                Image(systemName: directionToggle ? "chevron.down" : "chevron.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(type.accent)
                    .offset(y: -8)
                    .animation(.easeInOut(duration: 1.4), value: directionToggle)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(type.accent.opacity(0.7))
            VStack(spacing: 4) {
                Image(systemName: directionToggle ? "arrow.up" : "arrow.down")
                    .font(.system(size: 13, weight: .bold))
                Image(systemName: "doc.richtext")
                    .font(.system(size: 18))
            }
            .foregroundStyle(type.accent)
            .animation(.easeInOut(duration: 1.4), value: directionToggle)
        }
    }

    // MARK: Helpers

    private func keyCap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
            )
    }
}

// MARK: - Preview support

#if DEBUG
final class PreviewSettings: SettingsProtocol {
    @Published var isMonitoringActive: Bool = true
    @Published var invertDragDirection: Bool = false
    @Published var dragThreshold: Double = 40
    @Published var invertScroll: Bool = false
    @Published var enableScrollZoom: Bool = false
    @Published var enableMissionControl: Bool = true
    @Published var enableSpaceNavigation: Bool = true
    @Published var isDarkMode: Bool = false
    @Published var followSystemAppearance: Bool = true
    @Published var launchAtLogin: Bool = false

    func resetToDefaults() {}
}

#Preview("Full Settings") {
    ContentView(settings: PreviewSettings())
}

#Preview("Showcase only") {
    GestureShowcase(settings: PreviewSettings())
        .padding(32)
        .frame(width: 450)
}
#endif
