import SwiftUI

enum PermissionReadiness {
    case needsPermission, ready, paused, unavailable

    var canContinue: Bool { self == .ready || self == .paused }

    var descriptionKey: String {
        switch self {
        case .needsPermission: "permissions.card.description"
        case .ready: "permissions.success.description"
        case .paused: "permissions.paused.description"
        case .unavailable: "permissions.unavailable.description"
        }
    }
}

final class PermissionSetupState: ObservableObject {
    @Published var readiness: PermissionReadiness = .needsPermission
}

struct PermissionRequirementsView: View {
    static let contentWidth: CGFloat = 480

    @ObservedObject var state: PermissionSetupState
    let onActivate: () -> Void
    let onClose: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { state.readiness.canContinue ? .green : .blue }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 5) {
                    Text("permissions.welcome.title".localized)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                    Text("permissions.welcome.subtitle".localized)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    (state.readiness.canContinue ? "permissions.success.title" : "permissions.card.title").localized,
                    systemImage: state.readiness.canContinue ? "checkmark.seal.fill" : "accessibility"
                )
                .font(.headline)
                .foregroundStyle(accent)
                Text(state.readiness.descriptionKey.localized)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !state.readiness.canContinue {
                    Button(action: onActivate) {
                        Text((state.readiness == .needsPermission ? "permissions.card.activate" : "permissions.retry").localized)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            Text("permissions.automation.note".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if state.readiness.canContinue {
                    Text((state.readiness == .paused ? "permissions.paused.status" : "permissions.footer.ready").localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("permissions.footer.continue".localized, action: onClose)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Spacer()
                    Button("permissions.footer.later".localized, action: onClose)
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 20)
        .frame(width: Self.contentWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(Theme.accent)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state.readiness)
    }
}
