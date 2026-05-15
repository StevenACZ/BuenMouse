import AppKit

/// Floating helper card shown on top of System Settings. Contains the arrow
/// hint, the draggable BuenMouse card, and a fallback footnote.
final class PermissionOverlayContentView: NSView {
    static let preferredSize = NSSize(width: 520, height: 184)

    private let onClose: () -> Void

    init(hostApp: PermissionHostApp, accentColor: NSColor, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize))
        translatesAutoresizingMaskIntoConstraints = false
        setup(hostApp: hostApp, accentColor: accentColor)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(hostApp: PermissionHostApp, accentColor: NSColor) {
        let cardView = PermissionOverlayCardContainerView()
        addSubview(cardView)

        let arrowView = NSImageView()
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        arrowView.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: nil)
        arrowView.symbolConfiguration = .init(pointSize: 24, weight: .bold)
        arrowView.contentTintColor = accentColor
        cardView.addSubview(arrowView)

        let titleLabel = NSTextField(labelWithString: "Drag BuenMouse into Accessibility")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        cardView.addSubview(titleLabel)

        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        cardView.addSubview(closeButton)

        let messageLabel = NSTextField(wrappingLabelWithString: "Pick up the card below and drop it onto the Accessibility list. BuenMouse will appear there with its toggle already on.")
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        messageLabel.textColor = .secondaryLabelColor
        cardView.addSubview(messageLabel)

        let dragView = PermissionAppDragSourceView(hostApp: hostApp, accentColor: accentColor)
        cardView.addSubview(dragView)

        let footnoteLabel = NSTextField(wrappingLabelWithString: "Or click \"+\" in System Settings and pick BuenMouse manually.")
        footnoteLabel.translatesAutoresizingMaskIntoConstraints = false
        footnoteLabel.font = .systemFont(ofSize: 11, weight: .medium)
        footnoteLabel.textColor = .tertiaryLabelColor
        cardView.addSubview(footnoteLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.preferredSize.width),
            heightAnchor.constraint(equalToConstant: Self.preferredSize.height),

            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            arrowView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            arrowView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            arrowView.widthAnchor.constraint(equalToConstant: 24),
            arrowView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: arrowView.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: arrowView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12),

            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            messageLabel.leadingAnchor.constraint(equalTo: arrowView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -22),
            messageLabel.topAnchor.constraint(equalTo: arrowView.bottomAnchor, constant: 12),

            dragView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            dragView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            dragView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 14),
            dragView.heightAnchor.constraint(equalToConstant: 56),

            footnoteLabel.leadingAnchor.constraint(equalTo: dragView.leadingAnchor),
            footnoteLabel.trailingAnchor.constraint(equalTo: dragView.trailingAnchor),
            footnoteLabel.topAnchor.constraint(equalTo: dragView.bottomAnchor, constant: 10),
        ])
    }

    @objc
    private func closePressed() {
        onClose()
    }
}

private final class PermissionOverlayCardContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let backgroundAlpha: CGFloat = permissionUsesDarkAppearance ? 0.94 : 0.98
        let borderAlpha: CGFloat = permissionUsesDarkAppearance ? 0.26 : 0.16
        layer?.backgroundColor = permissionCGColor(.windowBackgroundColor, alpha: backgroundAlpha)
        layer?.borderColor = permissionCGColor(.separatorColor, alpha: borderAlpha)
    }
}
