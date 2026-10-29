import ServiceManagement
import SwiftUI
import TextCopyCore

struct SettingsView: View {
    /// Registers a shortcut and returns whether it was available.
    let applyShortcut: (Shortcut) -> Bool
    /// Releases the hotkey while a new one is being typed.
    let pauseShortcut: () -> Void

    @State private var shortcut: Shortcut
    @State private var isShortcutAvailable: Bool
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasScreenAccess = ScreenPermission.isGranted
    @AppStorage(Preferences.Key.language) private var language = ""
    @AppStorage(Preferences.Key.languageCorrection) private var languageCorrection = true
    @AppStorage(Preferences.Key.opensLinks) private var opensLinks = false
    @AppStorage(Preferences.Key.playsSound) private var playsSound = true

    private let languages: [(id: String, name: String)] = TextRecognizer.supportedLanguages
        .map { ($0.maximalIdentifier, Locale.current.localizedString(forIdentifier: $0.minimalIdentifier) ?? $0.minimalIdentifier) }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

    init(shortcut: Shortcut, isShortcutAvailable: Bool, applyShortcut: @escaping (Shortcut) -> Bool, pauseShortcut: @escaping () -> Void) {
        self.applyShortcut = applyShortcut
        self.pauseShortcut = pauseShortcut
        _shortcut = State(initialValue: shortcut)
        _isShortcutAvailable = State(initialValue: isShortcutAvailable)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Capture shortcut") {
                    ShortcutRecorder(shortcut: shortcut, onStart: pauseShortcut) { recorded in
                        shortcut = recorded
                        isShortcutAvailable = applyShortcut(recorded)
                    }
                }
                if !isShortcutAvailable {
                    Label("This shortcut is already used by another app. Choose a different one.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section("Recognition") {
                Picker("Language", selection: $language) {
                    Text("Automatic").tag("")
                    Divider()
                    ForEach(languages, id: \.id) { Text(verbatim: $0.name).tag($0.id) }
                }
                Toggle(isOn: $languageCorrection) {
                    Text("Language correction")
                    Text("Turn it off to copy code, links and serial numbers exactly as they appear.")
                }
            }

            Section("QR codes and barcodes") {
                Toggle(isOn: $opensLinks) {
                    Text("Open links automatically")
                    Text("Only web links (http and https) are opened.")
                }
            }

            Section("General") {
                Toggle("Confirmation sound", isOn: $playsSound)
                Toggle("Launch at login", isOn: $launchAtLogin)
            }

            Section("Permissions") {
                LabeledContent("Screen Recording") {
                    if hasScreenAccess {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Open System Settings", action: ScreenPermission.openSystemSettings)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .scrollIndicators(.never)
        .frame(width: 460)
        .fixedSize()
        .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasScreenAccess = ScreenPermission.isGranted
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
