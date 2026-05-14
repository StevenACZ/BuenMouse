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
struct GestureShowcase: View {
    private let items = GesturePreviewType.allCases
    private let autoAdvanceSeconds: TimeInterval = 4.5
    private let pauseAfterInteraction: TimeInterval = 10

    @State private var index: Int = 0
    @State private var autoTimer: Timer? = nil
    @State private var resumeTimer: Timer? = nil

    private var current: GesturePreviewType { items[index] }

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

            ZStack {
                ForEach(Array(items.enumerated()), id: \.offset) { offset, type in
                    GesturePreviewCard(type: type)
                        .opacity(offset == index ? 1 : 0)
                        .scaleEffect(offset == index ? 1 : 0.97)
                }
            }
            .frame(height: 96)
            .animation(.easeInOut(duration: 0.4), value: index)

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
        .onAppear { startAutoTimer() }
        .onDisappear { stopAllTimers() }
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

    @State private var phase: Double = 0
    @State private var directionToggle: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(type.accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(type.accent.opacity(0.20), lineWidth: 1)
                )

            content
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .onAppear { startAnimating() }
    }

    private func startAnimating() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            phase = 1.0
        }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            directionToggle = true
        }
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
            Circle()
                .fill(type.accent)
                .frame(width: 7, height: 7)
                .offset(y: -2)
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
                .offset(x: directionToggle ? -3 : 0)
            mouseWithHold
            Image(systemName: "arrow.right")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(type.accent)
                .opacity(directionToggle ? 0.25 : 1)
                .offset(x: directionToggle ? 0 : 3)
        }
        .animation(.easeInOut(duration: 2.2), value: directionToggle)
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

#Preview("Showcase") {
    GestureShowcase().padding(32).frame(width: 460)
}
