import AppKit
import Carbon.HIToolbox

/// A key combination in Carbon terms, plus the key's label for display.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String

    static let `default` = Shortcut(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(shiftKey | cmdKey), key: "2")

    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// Nil unless the event carries ⌘, ⌃ or ⌥: plain keys would hijack typing.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isDisjoint(with: [.command, .control, .option]) else { return nil }
        var modifiers = 0
        if flags.contains(.command) { modifiers |= cmdKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.control) { modifiers |= controlKey }
        if flags.contains(.shift) { modifiers |= shiftKey }
        let key = Self.specialKeys[Int(event.keyCode)]
            ?? event.characters(byApplyingModifiers: [])?.uppercased()
            ?? "?"
        self.init(keyCode: UInt32(event.keyCode), modifiers: UInt32(modifiers), key: key)
    }

    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        return flags
    }

    var displayString: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + key
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

/// System-wide hotkey through Carbon, which needs no Accessibility permission.
@MainActor
final class HotKey {
    private static var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?

    init(onPress: @escaping () -> Void) {
        Self.onPress = onPress
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon delivers hotkey events on the main thread.
            MainActor.assumeIsolated { HotKey.onPress?() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// Returns false when the combination is already taken.
    func register(_ shortcut: Shortcut) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x5458_4350), id: 1)  // 'TXCP'
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref
        )
        return status == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}
