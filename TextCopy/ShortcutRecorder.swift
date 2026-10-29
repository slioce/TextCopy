import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Button that records the next key combination; Esc cancels.
struct ShortcutRecorder: View {
    let shortcut: Shortcut
    let onStart: () -> Void
    /// Called with the new combination, or the old one when recording was cancelled.
    let onFinish: (Shortcut) -> Void
    @State private var monitor: Any?

    var body: some View {
        Button {
            if monitor == nil { start() } else { finish(with: shortcut) }
        } label: {
            if monitor == nil {
                Text(verbatim: shortcut.displayString)
            } else {
                Text("Type a shortcut…")
            }
        }
        .frame(minWidth: 120)
        .onDisappear { finish(with: shortcut) }
    }

    private func start() {
        onStart()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                finish(with: shortcut)
            } else if let recorded = Shortcut(event: event) {
                finish(with: recorded)
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func finish(with result: Shortcut) {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        onFinish(result)
    }
}
