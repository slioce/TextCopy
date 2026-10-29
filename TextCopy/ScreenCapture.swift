import CoreGraphics
import Foundation
import ImageIO

/// Interactive selection through macOS's own `screencapture`: crosshair, Space for a whole window, Esc to cancel.
///
/// The child process inherits the App Sandbox and registers the Mach service `com.apple.screencapture.interactive`,
/// which the sandbox would deny; `TextCopy.entitlements` carries a `mach-register.global-name` exception for it.
enum ScreenCapture {
    static func selectArea() async -> CGImage? {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("TextCopy-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: file) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", "-o", "-r", file.path]
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in continuation.resume() }
            do { try process.run() } catch { continuation.resume() }
        }

        // Cancelling leaves no file behind.
        guard let data = try? Data(contentsOf: file),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
