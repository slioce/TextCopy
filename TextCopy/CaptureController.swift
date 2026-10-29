import AppKit
import TextCopyCore

/// One capture: permission check, system selection, OCR, clipboard, feedback.
@MainActor
final class CaptureController {
    private let feedback: Feedback
    private var isCapturing = false

    init(feedback: Feedback) {
        self.feedback = feedback
    }

    func capture() {
        guard !isCapturing else { return }
        guard ScreenPermission.isGranted else {
            ScreenPermission.requestOrExplain()
            return
        }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            guard let image = await ScreenCapture.selectArea() else { return }
            let result = (try? await Preferences.recognizer.recognize(image)) ?? .empty
            deliver(result)
        }
    }

    private func deliver(_ result: RecognitionResult) {
        if let string = result.string {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
        feedback.show(result)
        if case .barcodes(let payloads, _) = result, Preferences.opensLinks {
            openFirstWebLink(in: payloads)
        }
    }

    /// Web links only: a QR code must not be able to launch apps or open local files.
    private func openFirstWebLink(in payloads: [String]) {
        let link = payloads.lazy.compactMap { URL(string: $0) }.first { url in
            guard let scheme = url.scheme?.lowercased() else { return false }
            return scheme == "http" || scheme == "https"
        }
        if let link { NSWorkspace.shared.open(link) }
    }
}
