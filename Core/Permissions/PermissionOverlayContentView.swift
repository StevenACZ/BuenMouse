import AppKit

/// Floating helper card shown on top of System Settings. Contains the arrow
/// hint, the draggable BuenMouse card, and a fallback footnote.
final class PermissionOverlayContentView: NSView {
    static let preferredSize = NSSize(width: 400, height: 190)

    private let onClose: () -> Void
    private var measurementWidth: NSLayoutConstraint?
    private var measuredSize: NSSize?
    private var wrappingLabels: [(NSTextField, CGFloat)] = []

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

    func preferredHeight(for width: CGFloat) -> CGFloat {
        if let measuredSize, measuredSize.width == width { return measuredSize.height }
        measurementWidth?.constant = width
        for (label, inset) in wrappingLabels {
            label.preferredMaxLayoutWidth = max(1, width - inset)
            label.invalidateIntrinsicContentSize()
        }
        layoutSubtreeIfNeeded()
        let height = ceil(fittingSize.height)
        measuredSize = NSSize(width: width, height: height)
        return height
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

        let titleLabel = NSTextField(wrappingLabelWithString: "overlay.title".localized)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        cardView.addSubview(titleLabel)

        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isBordered = false
        closeButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill", accessibilityDescription: "overlay.close".localized)
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        cardView.addSubview(closeButton)

        let messageLabel = NSTextField(wrappingLabelWithString: "overlay.message".localized)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        messageLabel.textColor = .secondaryLabelColor
        cardView.addSubview(messageLabel)

        let dragView = PermissionAppDragSourceView(hostApp: hostApp, accentColor: accentColor)
        cardView.addSubview(dragView)

        let footnoteLabel = NSTextField(wrappingLabelWithString: "overlay.footnote".localized)
        footnoteLabel.translatesAutoresizingMaskIntoConstraints = false
        footnoteLabel.font = .systemFont(ofSize: 11, weight: .medium)
        footnoteLabel.textColor = .tertiaryLabelColor
        cardView.addSubview(footnoteLabel)

        wrappingLabels = [(titleLabel, 108), (messageLabel, 46), (footnoteLabel, 48)]
        measurementWidth = widthAnchor.constraint(equalToConstant: Self.preferredSize.width)
        measurementWidth?.isActive = true
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            arrowView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            arrowView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            arrowView.widthAnchor.constraint(equalToConstant: 24),
            arrowView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: arrowView.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: arrowView.topAnchor),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12),

            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            messageLabel.leadingAnchor.constraint(equalTo: arrowView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -22),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),

            dragView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            dragView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            dragView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 14),
            dragView.heightAnchor.constraint(equalToConstant: 64),

            footnoteLabel.leadingAnchor.constraint(equalTo: dragView.leadingAnchor),
            footnoteLabel.trailingAnchor.constraint(equalTo: dragView.trailingAnchor),
            footnoteLabel.topAnchor.constraint(equalTo: dragView.bottomAnchor, constant: 10),
            footnoteLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -18),
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
