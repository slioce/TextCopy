import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// There is no main nib, so `NSApplicationMain` would never create the delegate.
    /// `NSApplication.delegate` is weak, so the instance must outlive `run()`.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let captureItem = NSMenuItem(title: String(localized: "Capture Text"), action: #selector(capture), keyEquivalent: "")
    private let conflictItem = NSMenuItem(title: String(localized: "Shortcut in use by another app"), action: nil, keyEquivalent: "")
    private lazy var controller = CaptureController(feedback: Feedback(statusButton: statusItem.button))
    private lazy var hotKey = HotKey { [weak self] in self?.capture() }
    private var isShortcutAvailable = true
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.register()
        statusItem.button?.image = StatusIcon.idle

        let settingsItem = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        let quitItem = NSMenuItem(title: String(localized: "Quit TextCopy"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        captureItem.target = self
        settingsItem.target = self
        conflictItem.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
        let menu = NSMenu()
        menu.items = [captureItem, conflictItem, .separator(), settingsItem, quitItem]
        statusItem.menu = menu

        _ = controller  // preloads the confirmation sounds
        apply(Preferences.shortcut)
        warmUpRecognizerIfNeeded()
    }

    /// Once per app and macOS version, so the first capture doesn't wait for Vision to compile its models.
    private func warmUpRecognizerIfNeeded() {
        let stamp = "\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "")/\(ProcessInfo.processInfo.operatingSystemVersionString)"
        guard UserDefaults.standard.string(forKey: Preferences.Key.warmedUpFor) != stamp else { return }
        let recognizer = Preferences.recognizer
        Task.detached(priority: .utility) {
            await recognizer.warmUp()
            UserDefaults.standard.set(stamp, forKey: Preferences.Key.warmedUpFor)
        }
    }

    @objc private func capture() {
        controller.capture()
    }

    /// Registers the hotkey and mirrors it in the menu; returns whether the combination was available.
    @discardableResult
    private func apply(_ shortcut: Shortcut) -> Bool {
        isShortcutAvailable = hotKey.register(shortcut)
        captureItem.keyEquivalent = shortcut.key.count == 1 ? shortcut.key.lowercased() : ""
        captureItem.keyEquivalentModifierMask = shortcut.modifierFlags
        conflictItem.isHidden = isShortcutAvailable
        return isShortcutAvailable
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                shortcut: Preferences.shortcut,
                isShortcutAvailable: isShortcutAvailable,
                applyShortcut: { [weak self] shortcut in
                    Preferences.shortcut = shortcut
                    return self?.apply(shortcut) ?? false
                },
                pauseShortcut: { [weak self] in self?.hotKey.unregister() }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = String(localized: "TextCopy Settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
        // macOS may decline the activation request from a menu bar app; this still brings the
        // window in front of the others once, without keeping it on top.
        settingsWindow?.orderFrontRegardless()
    }

    /// Drops the SwiftUI hierarchy so nothing stays in memory while settings are closed.
    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}
