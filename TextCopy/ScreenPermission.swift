import AppKit

enum ScreenPermission {
    static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// Per launch, not persisted: the system decides whether to prompt again (for example after the app's
    /// signature changed), and a stale "already asked" flag would hide that prompt behind our own alert.
    @MainActor private static var didRequest = false

    static func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    /// Lets the system prompt first; after that, explain where to turn it on.
    @MainActor
    static func requestOrExplain() {
        guard didRequest else {
            didRequest = true
            CGRequestScreenCaptureAccess()
            return
        }
        let alert = NSAlert()
        alert.messageText = String(localized: "Screen Recording permission needed")
        alert.informativeText = String(localized: "TextCopy needs to see the area you select to read its text. Turn on TextCopy in System Settings › Privacy & Security › Screen & System Audio Recording, then reopen the app. If it is already on, turn it off and on again.")
        alert.addButton(withTitle: String(localized: "Open System Settings"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { openSystemSettings() }
    }
}
