import AppKit

/// Small floating panel that confirms a capture without taking focus or clicks.
@MainActor
final class HUD {
    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let row = NSStackView()
    private var hideTask: Task<Void, Never>?

    init() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        icon.symbolConfiguration = .init(pointSize: 26, weight: .semibold)
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        detail.maximumNumberOfLines = 1

        let labels = NSStackView(views: [title, detail])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        row.setViews([icon, labels], in: .leading)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 22)
        detail.widthAnchor.constraint(lessThanOrEqualToConstant: 320).isActive = true

        panel.contentView = Self.background(around: row)
    }

    func show(symbol: String, tint: NSColor, title: String, detail: String?) {
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = tint
        self.title.stringValue = title
        self.detail.stringValue = detail ?? ""
        self.detail.isHidden = detail == nil

        guard let content = panel.contentView, let screen = Self.screenUnderMouse() else { return }
        // Measure the stack itself: the glass container doesn't report its content's size.
        let size = row.fittingSize
        let visible = screen.visibleFrame
        panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.minY + 96, width: size.width, height: size.height), display: true)
        panel.invalidateShadow()

        hideTask?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
        Self.pop(content)
        icon.addSymbolEffect(.bounce)

        hideTask = Task { [panel] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }

    /// Liquid Glass where available, the classic HUD material otherwise.
    private static func background(around content: NSView) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = 18
            content.autoresizingMask = [.width, .height]
            glass.contentView = content
            return glass
        }
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 18
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        content.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            content.topAnchor.constraint(equalTo: effect.topAnchor),
            content.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        return effect
    }

    private static func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    /// Springs the panel up from slightly smaller, scaling around its center.
    private static func pop(_ view: NSView) {
        view.wantsLayer = true
        guard let layer = view.layer else { return }
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: view.frame.midX, y: view.frame.midY)
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.85
        spring.toValue = 1
        spring.damping = 14
        spring.stiffness = 260
        spring.duration = spring.settlingDuration
        layer.add(spring, forKey: "pop")
    }
}
