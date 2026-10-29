// swift-tools-version: 6.0
import PackageDescription

// The OCR engine, kept apart from the app so it can be tested with `swift test` alone.
let package = Package(
    name: "TextCopyCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "TextCopyCore", targets: ["TextCopyCore"])],
    targets: [
        .target(name: "TextCopyCore"),
        .testTarget(name: "TextCopyCoreTests", dependencies: ["TextCopyCore"]),
    ]
)
