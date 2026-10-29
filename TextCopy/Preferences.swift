import Foundation
import TextCopyCore

enum Preferences {
    enum Key {
        static let shortcut = "shortcut"
        static let language = "recognitionLanguage"
        static let languageCorrection = "languageCorrection"
        static let opensLinks = "opensBarcodeLinks"
        static let playsSound = "playsSound"
        static let warmedUpFor = "warmedUpFor"
    }

    static func register() {
        UserDefaults.standard.register(defaults: [
            Key.language: "",
            Key.languageCorrection: true,
            Key.opensLinks: false,
            Key.playsSound: true,
        ])
    }

    static var shortcut: Shortcut {
        get {
            UserDefaults.standard.data(forKey: Key.shortcut)
                .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .default
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: Key.shortcut) }
    }

    /// A recognizer configured from the current settings; an empty language means automatic.
    static var recognizer: TextRecognizer {
        let language = UserDefaults.standard.string(forKey: Key.language) ?? ""
        return TextRecognizer(
            languages: language.isEmpty ? [] : [Locale.Language(identifier: language)],
            usesLanguageCorrection: UserDefaults.standard.bool(forKey: Key.languageCorrection)
        )
    }

    static var opensLinks: Bool { UserDefaults.standard.bool(forKey: Key.opensLinks) }
    static var playsSound: Bool { UserDefaults.standard.bool(forKey: Key.playsSound) }
}
