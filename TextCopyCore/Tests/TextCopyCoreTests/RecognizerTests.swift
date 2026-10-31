import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreText
import Testing
@testable import TextCopyCore

struct RecognitionResultTests {
    @Test func joinsLinesAndTrims() {
        let result = RecognitionResult(lines: ["  first line", "second line  "], barcodes: [])
        #expect(result == .text("first line\nsecond line"))
    }

    @Test func barcodeWinsOverText() {
        let result = RecognitionResult(lines: ["Scan me"], barcodes: [.init(payload: "https://example.com", isQR: true)])
        #expect(result == .barcodes(["https://example.com"], isQR: true))
    }

    @Test func duplicateAndEmptyPayloadsAreDropped() {
        let result = RecognitionResult(lines: [], barcodes: [
            .init(payload: "A", isQR: false), .init(payload: "", isQR: true), .init(payload: "A", isQR: false), .init(payload: "B", isQR: false),
        ])
        #expect(result == .barcodes(["A", "B"], isQR: false))
        #expect(result.string == "A\nB")
    }

    @Test func nothingIsEmpty() {
        let result = RecognitionResult(lines: ["   "], barcodes: [])
        #expect(result == .empty)
        #expect(result.string == nil)
    }
}

struct TextRecognizerTests {
    @Test func recognizesRenderedText() async throws {
        let image = try Canvas(width: 1400, height: 200).text("The quick brown fox jumps over the lazy dog", at: CGPoint(x: 40, y: 80)).image()
        let result = try await TextRecognizer().recognize(image)
        #expect(result == .text("The quick brown fox jumps over the lazy dog"))
    }

    @Test func keepsLineBreaks() async throws {
        let image = try Canvas(width: 900, height: 300)
            .text("Hello world", at: CGPoint(x: 40, y: 180))
            .text("Second line here", at: CGPoint(x: 40, y: 60))
            .image()
        let result = try await TextRecognizer().recognize(image)
        #expect(result == .text("Hello world\nSecond line here"))
    }

    @Test func qrCodeTakesPriority() async throws {
        let payload = "https://example.com/textcopy?id=42"
        let image = try Canvas(width: 1000, height: 500)
            .text("Scan this code", at: CGPoint(x: 40, y: 220))
            .qrCode(payload, at: CGPoint(x: 600, y: 60), size: 360)
            .image()
        let result = try await TextRecognizer().recognize(image)
        #expect(result == .barcodes([payload], isQR: true))
    }

    @Test func blankImageIsEmpty() async throws {
        let image = try Canvas(width: 400, height: 200).image()
        let result = try await TextRecognizer().recognize(image)
        #expect(result == .empty)
    }

    /// The warm-up must go through the same path as a real capture, so its sample has to be readable text.
    @Test func warmUpSampleReadsLikeACapture() async throws {
        let image = try #require(TextRecognizer.sampleImage())
        #expect(image.width >= 1200 && image.height >= 300)
        let result = try await TextRecognizer().recognize(image)
        #expect(result.string?.contains("quick brown fox") == true)
    }
}

/// White canvas to draw test fixtures on.
private final class Canvas {
    private let context: CGContext

    init(width: Int, height: Int) {
        context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }

    func text(_ string: String, at point: CGPoint) -> Canvas {
        let font = CTFontCreateWithName("Helvetica" as CFString, 48, nil)
        let attributed = NSAttributedString(string: string, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
        ])
        context.textPosition = point
        CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        return self
    }

    func qrCode(_ payload: String, at point: CGPoint, size: CGFloat) -> Canvas {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        let output = filter.outputImage!
        let qr = CIContext().createCGImage(output, from: output.extent)!
        context.interpolationQuality = .none
        context.draw(qr, in: CGRect(origin: point, size: CGSize(width: size, height: size)))
        return self
    }

    func image() throws -> CGImage {
        try #require(context.makeImage())
    }
}
