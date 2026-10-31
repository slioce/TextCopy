import CoreGraphics
import CoreText
import Foundation
import Vision

/// Reads text and barcodes from an image in a single Vision pass.
public struct TextRecognizer: Sendable {
    /// Empty means automatic language detection.
    public var languages: [Locale.Language]
    public var usesLanguageCorrection: Bool

    public init(languages: [Locale.Language] = [], usesLanguageCorrection: Bool = true) {
        self.languages = languages
        self.usesLanguageCorrection = usesLanguageCorrection
    }

    public static var supportedLanguages: [Locale.Language] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        return request.supportedRecognitionLanguages
    }

    /// Vision compiles its models the first time an app uses them, which can take up to a minute.
    /// Running once on a rendered sample moves that cost out of the first real capture.
    public func warmUp() async {
        guard let sample = Self.sampleImage() else { return }
        _ = try? await recognize(sample)
    }

    public func recognize(_ image: CGImage) async throws -> RecognitionResult {
        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = usesLanguageCorrection
        if languages.isEmpty {
            textRequest.automaticallyDetectsLanguage = true
        } else {
            textRequest.recognitionLanguages = languages
        }

        let (observations, barcodes) = try await ImageRequestHandler(image).perform(textRequest, DetectBarcodesRequest())
        return RecognitionResult(
            lines: observations.compactMap { $0.topCandidates(1).first?.string },
            barcodes: barcodes.compactMap { observation in
                observation.payloadString.map { .init(payload: $0, isQR: observation.symbology == .qr || observation.symbology == .microQR) }
            }
        )
    }

    /// About a Retina screenshot of two lines of text, so the warm-up runs the same models as a real capture.
    static func sampleImage() -> CGImage? {
        let width = 1600, height = 400
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 48, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
        ]
        for (index, line) in ["TextCopy warm-up 123", "The quick brown fox jumps over the lazy dog"].enumerated() {
            context.textPosition = CGPoint(x: 40, y: 260 - index * 120)
            CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: attributes)), context)
        }
        return context.makeImage()
    }
}
