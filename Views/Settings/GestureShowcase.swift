import SwiftUI

// MARK: - Gesture Showcase

/// Auto-rotating carousel that demonstrates each gesture one at a time.
/// Placed once at the top of SettingsView so toggles below stay clean.
struct GestureShowcase<Settings: SettingsProtocol>: View {
    @ObservedObject var settings: Settings
    @ObservedObject private var localizationManager = LocalizationManager.shared
    /// Lets the parent know which slide is on screen so it can adjust the
    /// surrounding layout (e.g. center short slides, top-align the long one).
    var onSlideChange: ((GesturePreviewType) -> Void)? = nil

    private let items = GesturePreviewType.allCases
    private let autoAdvanceSeconds: TimeInterval = 10
    private let pauseAfterInteraction: TimeInterval = 30

    @State private var index: Int = 0
    @State private var autoTimer: Timer? = nil
    @State private var resumeTimer: Timer? = nil
    @State private var cardPressed: Bool = false

    private var current: GesturePreviewType { items[index] }

    /// Binds the current slide to the matching settings property.
    private var currentBinding: Binding<Bool> {
        switch current {
        case .missionControl: return $settings.enableMissionControl
        case .spaceNavigation: return $settings.enableSpaceNavigation
        case .scrollZoom: return $settings.enableScrollZoom
        case .invertScroll: return $settings.invertScroll
        }
    }

    private var canToggle: Bool { settings.isMonitoringActive }
    private var isCurrentOn: Bool { canToggle && currentBinding.wrappedValue }

    private func isEnabled(_ type: GesturePreviewType) -> Bool {
        guard settings.isMonitoringActive else { return false }
        switch type {
        case .missionControl: return settings.enableMissionControl
        case .spaceNavigation: return settings.enableSpaceNavigation
        case .scrollZoom: return settings.enableScrollZoom
        case .invertScroll: return settings.invertScroll
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
                        GesturePreviewCard(
                            type: type,
                            isActive: isEnabled(type),
                            inverted: type == .spaceNavigation && settings.invertDragDirection
                        )
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
            .help(
                canToggle
                    ? (isCurrentOn
                        ? "showcase.card.help.disable".localized
                        : "showcase.card.help.enable".localized)
                    : "showcase.card.help.monitoring_off".localized)

            // No inline toggles — the On/Off badge plus card-tap handle activation.
            // Space Navigation's extras (slider + invert drag) appear only when ON.
            if current == .spaceNavigation && settings.enableSpaceNavigation {
                spaceNavExtras
                    .transition(
                        .asymmetric(
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
        .onAppear {
            startAutoTimer()
            onSlideChange?(current)
        }
        .onChange(of: index) { _, _ in onSlideChange?(current) }
        .onDisappear { stopAllTimers() }
    }

    @ViewBuilder
    private var spaceNavExtras: some View {
        let extrasDisabled = !canToggle || !settings.enableSpaceNavigation
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("showcase.drag_distance".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(settings.dragThreshold)) px")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(extrasDisabled ? .secondary : .primary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: settings.dragThreshold)

                Toggle(
                    isOn: Binding(
                        get: { settings.invertDragDirection },
                        set: { newValue in
                            settings.invertDragDirection = newValue
                            pauseAndScheduleResume()
                        }
                    )
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("showcase.invert".localized)
                            .font(.caption)
                    }
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .disabled(extrasDisabled)
                .help("showcase.invert.help".localized)
            }

            Slider(
                value: $settings.dragThreshold,
                in: 50...250,
                step: 50,
                onEditingChanged: { editing in
                    if editing { pauseAndScheduleResume() }
                }
            )
            .tint(current.accent)
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
            Text(on ? "showcase.badge.on".localized : "showcase.badge.off".localized)
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
    /// Only used by `.spaceNavigation` — when true, mirrors the mouse motion
    /// and arrows horizontally so the user sees the drag direction reverse.
    var inverted: Bool = false

    @State private var directionToggle: Bool = false
    @State private var rippleProgress: CGFloat = 0
    @State private var clickPulse: CGFloat = 0
    @State private var missionGlyphSpread: CGFloat = 0
    @State private var directionTimer: Timer? = nil
    @State private var clickTimer: Timer? = nil

    private let directionInterval: TimeInterval = 1.6
    private let clickInterval: TimeInterval = 1.6

    /// Animation speed multiplier — slows everything down when the gesture is
    /// disabled so the card feels "dormant" alongside the desaturated look.
    private var slowFactor: Double { isActive ? 1.0 : 3.5 }
    private var dirInt: TimeInterval { directionInterval * slowFactor }
    private var clickInt: TimeInterval { clickInterval * slowFactor }

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
        .onChange(of: isActive) { _, _ in startAnimating() }
        .onDisappear { stopAnimating() }
    }

    private func startAnimating() {
        stopAnimating()
        switch type {
        case .missionControl:
            fireMissionClick()
            clickTimer = Timer.scheduledTimer(withTimeInterval: clickInt, repeats: true) { _ in
                fireMissionClick()
            }
        case .spaceNavigation:
            runDirectionStep()
            directionTimer = Timer.scheduledTimer(withTimeInterval: dirInt, repeats: true) { _ in
                runDirectionStep()
            }
        case .scrollZoom, .invertScroll:
            directionTimer = Timer.scheduledTimer(withTimeInterval: dirInt, repeats: true) { [dirInt] _ in
                withAnimation(.easeInOut(duration: dirInt)) {
                    directionToggle.toggle()
                }
            }
        }
    }

    /// Flip the mouse's direction and schedule a click pulse for the moment it
    /// crosses the center, so the wave only fires while at the midpoint.
    private func runDirectionStep() {
        let duration = dirInt
        withAnimation(.easeInOut(duration: duration)) {
            directionToggle.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration / 2) {
            fireClickPulse()
        }
    }

    /// Fires a click for Mission Control: pulse + ripple + toggle the glyph spread
    /// so the three rectangles separate and rejoin on alternating clicks.
    private func fireMissionClick() {
        fireClickPulse()
        withAnimation(.spring(response: 0.5 * slowFactor, dampingFraction: 0.65)) {
            missionGlyphSpread = missionGlyphSpread > 0.5 ? 0 : 1
        }
    }

    /// Pulse the dot and emit a ripple — the visible "click registered" cue.
    private func fireClickPulse() {
        let factor = slowFactor
        var snap = Transaction(animation: nil)
        snap.disablesAnimations = true
        withTransaction(snap) { rippleProgress = 0 }
        withAnimation(.easeOut(duration: 0.95 * factor)) {
            rippleProgress = 1
        }
        withAnimation(.easeOut(duration: 0.16 * factor)) {
            clickPulse = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16 * factor) {
            withAnimation(.easeInOut(duration: 0.4 * factor)) {
                clickPulse = 0
            }
        }
    }

    private func stopAnimating() {
        directionTimer?.invalidate()
        directionTimer = nil
        clickTimer?.invalidate()
        clickTimer = nil
    }

    @ViewBuilder
    private var content: some View {
        switch type {
        case .missionControl: missionControl
        case .spaceNavigation: spaceNavigation
        case .scrollZoom: scrollZoom
        case .invertScroll: invertScroll
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
        clickIndicatorMouse
    }

    private var mouseWithHold: some View {
        clickIndicatorMouse
    }

    /// Shared mouse + centered click indicator: a dot that squishes on click,
    /// with an outer ring that expands and fades as the "click wave".
    private var clickIndicatorMouse: some View {
        ZStack(alignment: .top) {
            mouse
            ZStack {
                Circle()
                    .stroke(type.accent, lineWidth: 1.4)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1 + 2.5 * rippleProgress)
                    .opacity(Double(1 - rippleProgress))
                Circle()
                    .fill(type.accent)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.0 + 0.55 * clickPulse)
                    .opacity(0.85)
            }
            .offset(y: 12)
        }
    }

    /// Mission Control glyph approximating `rectangle.3.group.fill`. The 3
    /// rectangles separate when `missionGlyphSpread` = 1 and rejoin at 0.
    private var missionGlyph: some View {
        let leftWidth: CGFloat = 13
        let leftHeight: CGFloat = 28
        let rightWidth: CGFloat = 11
        let rightHeight: CGFloat = 11
        let horizontalGap: CGFloat = 2 + 5 * missionGlyphSpread
        let verticalGap: CGFloat = 5 + 6 * missionGlyphSpread

        return HStack(spacing: horizontalGap) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(type.accent)
                .frame(width: leftWidth, height: leftHeight)
                .offset(x: -2 * missionGlyphSpread)
            VStack(spacing: verticalGap) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(type.accent)
                    .frame(width: rightWidth, height: rightHeight)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(type.accent)
                    .frame(width: rightWidth, height: rightHeight)
            }
            .offset(x: 2 * missionGlyphSpread)
        }
        .frame(height: leftHeight)
    }

    // MARK: Variants

    private var missionControl: some View {
        HStack(spacing: 22) {
            mouseWithClick
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(type.accent.opacity(0.7))
            missionGlyph
        }
    }

    private var spaceNavigation: some View {
        // The filled square is on the same side the mouse drifts toward when
        // not inverted, and on the OPPOSITE side when inverted. Because the
        // computed position depends on `directionToggle`, and that toggle is
        // changed inside a withAnimation block, the filled square slides
        // continuously alongside the mouse animation — so it crosses the
        // center exactly when the mouse does.
        let goingLeft = directionToggle
        let filledOnLeft = goingLeft != inverted
        let slotWidth: CGFloat = 18
        let slotHeight: CGFloat = 22
        let slotGap: CGFloat = 6

        return HStack(spacing: 36) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(type.accent)
                    .opacity(goingLeft ? 1 : 0.25)
                    .scaleEffect(goingLeft ? 1.15 : 0.9)
                mouseWithHold
                    .offset(x: goingLeft ? -8 : 8)
                    .rotationEffect(.degrees(goingLeft ? -3 : 3))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(type.accent)
                    .opacity(goingLeft ? 0.25 : 1)
                    .scaleEffect(goingLeft ? 0.9 : 1.15)
            }

            // Two outline slots with a single filled square sliding between
            // them. The slide tracks the mouse animation 1:1.
            ZStack(alignment: .leading) {
                HStack(spacing: slotGap) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(type.accent.opacity(0.35), lineWidth: 1.2)
                        .frame(width: slotWidth, height: slotHeight)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(type.accent.opacity(0.35), lineWidth: 1.2)
                        .frame(width: slotWidth, height: slotHeight)
                }
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(type.accent)
                    .frame(width: slotWidth, height: slotHeight)
                    .offset(x: filledOnLeft ? 0 : (slotWidth + slotGap))
            }
            .frame(width: slotWidth * 2 + slotGap, height: slotHeight)
        }
        .animation(.easeInOut(duration: 0.45), value: inverted)
    }

    private var scrollZoom: some View {
        HStack(spacing: 12) {
            keyCap("⌃")
            Text("+")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            ZStack {
                mouse
                VStack(spacing: 1) {
                    Image(systemName: "chevron.up")
                        .opacity(directionToggle ? 1 : 0.18)
                        .scaleEffect(directionToggle ? 1.35 : 0.7, anchor: .bottom)
                        .offset(y: directionToggle ? -3 : 1)
                    Image(systemName: "chevron.down")
                        .opacity(directionToggle ? 0.18 : 1)
                        .scaleEffect(directionToggle ? 0.7 : 1.35, anchor: .top)
                        .offset(y: directionToggle ? -1 : 3)
                }
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(type.accent)
                .offset(y: -8)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(type.accent.opacity(0.7))
            Image(systemName: directionToggle ? "plus.magnifyingglass" : "minus.magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(type.accent)
                .scaleEffect(directionToggle ? 1.35 : 0.75)
                .rotationEffect(.degrees(directionToggle ? -6 : 6))
        }
    }

    private var invertScroll: some View {
        HStack(spacing: 22) {
            ZStack {
                mouse
                VStack(spacing: 1) {
                    Image(systemName: "chevron.up")
                        .opacity(directionToggle ? 0.18 : 1)
                        .scaleEffect(directionToggle ? 0.7 : 1.35, anchor: .bottom)
                        .offset(y: directionToggle ? 1 : -3)
                    Image(systemName: "chevron.down")
                        .opacity(directionToggle ? 1 : 0.18)
                        .scaleEffect(directionToggle ? 1.35 : 0.7, anchor: .top)
                        .offset(y: directionToggle ? 3 : -1)
                }
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(type.accent)
                .offset(y: -8)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(type.accent.opacity(0.7))
            // Page indicator: the document slides in the same direction as the
            // wheel — i.e., scroll wheel down → page goes down (natural/inverted).
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(type.accent)
                .offset(y: directionToggle ? 10 : -10)
                .scaleEffect(directionToggle ? 1.05 : 0.95)
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
        @Published var dragThreshold: Double = 100
        @Published var invertScroll: Bool = false
        @Published var enableScrollZoom: Bool = false
        @Published var enableMissionControl: Bool = true
        @Published var enableSpaceNavigation: Bool = true
        @Published var launchAtLogin: Bool = false

        func resetToDefaults() {}
    }

    #Preview("Showcase only") {
        GestureShowcase(settings: PreviewSettings())
            .padding(32)
            .frame(width: 450)
    }
#endif
