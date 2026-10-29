import AppKit
import TextCopyCore

@MainActor
enum StatusIcon {
    static let idle = symbol("text.viewfinder")
    static let done = symbol("checkmark")

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "TextCopy")
        image?.isTemplate = true
        return image
    }
}

/// Confirms a capture with the HUD, a sound and a brief checkmark in the menu bar.
@MainActor
final class Feedback {
    private let hud = HUD()
    // Loaded up front so the first confirmation plays without delay.
    private let copiedSound = NSSound(named: "Pop")
    private let emptySound = NSSound(named: "Funk")
    private weak var statusButton: NSStatusBarButton?
    private var restoreIcon: Task<Void, Never>?

    init(statusButton: NSStatusBarButton?) {
        self.statusButton = statusButton
    }

    func show(_ result: RecognitionResult) {
        switch result {
        case .text(let text):
            confirm(String(localized: "Copied"), preview: text)
        case .barcodes(let payloads, let isQR):
            confirm(isQR ? String(localized: "QR code copied") : String(localized: "Barcode copied"),
                    preview: payloads.joined(separator: " "))
        case .empty:
            hud.show(symbol: "text.magnifyingglass", tint: .secondaryLabelColor, title: String(localized: "No text found"), detail: nil)
            play(emptySound)
        }
    }

    private func confirm(_ title: String, preview: String) {
        hud.show(symbol: "checkmark.circle.fill", tint: .systemGreen, title: title, detail: Self.preview(of: preview))
        play(copiedSound)
        flashCheckmark()
    }

    private func play(_ sound: NSSound?) {
        guard Preferences.playsSound, let sound else { return }
        sound.stop()
        sound.play()
    }

    private func flashCheckmark() {
        guard let button = statusButton else { return }
        restoreIcon?.cancel()
        button.image = StatusIcon.done
        restoreIcon = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            button.image = StatusIcon.idle
        }
    }

    private static func preview(of text: String, limit: Int = 60) -> String {
        let line = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return line.count > limit ? String(line.prefix(limit)) + "…" : line
    }
}
