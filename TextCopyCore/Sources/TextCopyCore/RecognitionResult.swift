/// What a capture produced, already reduced to the one thing worth copying.
public enum RecognitionResult: Equatable, Sendable {
    case text(String)
    case barcodes([String], isQR: Bool)
    case empty

    public struct Barcode: Equatable, Sendable {
        public var payload: String
        public var isQR: Bool

        public init(payload: String, isQR: Bool) {
            self.payload = payload
            self.isQR = isQR
        }
    }

    /// Barcodes win over text: a selection around a QR code is almost always about its content.
    public init(lines: [String], barcodes: [Barcode]) {
        var seen = Set<String>()
        let found = barcodes.filter { !$0.payload.isEmpty && seen.insert($0.payload).inserted }
        if !found.isEmpty {
            self = .barcodes(found.map(\.payload), isQR: found.contains(where: \.isQR))
            return
        }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        self = text.isEmpty ? .empty : .text(text)
    }

    /// The string to put on the clipboard, or nil when nothing was found.
    public var string: String? {
        switch self {
        case .text(let text): text
        case .barcodes(let payloads, _): payloads.joined(separator: "\n")
        case .empty: nil
        }
    }
}
