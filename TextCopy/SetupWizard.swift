import SwiftUI

/// First-launch setup: asks for Screen Recording, then waits for text recognition to be ready.
struct SetupWizard: View {
    let shortcut: Shortcut
    /// The warm-up started at launch; the wizard only waits for it.
    let preparation: Task<Void, Never>
    let onFinish: () -> Void

    private enum Step: Int, CaseIterable {
        case permission, preparing, ready
    }

    @State private var step: Step
    @State private var hasScreenAccess: Bool
    @State private var didAskForAccess: Bool
    @State private var isPrepared = false

    init(shortcut: Shortcut, preparation: Task<Void, Never>, onFinish: @escaping () -> Void) {
        self.shortcut = shortcut
        self.preparation = preparation
        self.onFinish = onFinish
        // macOS usually relaunches the app once the permission is granted: pick up after that step.
        let isGranted = ScreenPermission.isGranted
        _step = State(initialValue: isGranted ? .preparing : .permission)
        _hasScreenAccess = State(initialValue: isGranted)
        _didAskForAccess = State(initialValue: ScreenPermission.didRequest)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .permission: permissionPage
                case .preparing: preparingPage
                case .ready: readyPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { item in
                    Circle()
                        .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(EdgeInsets(top: 28, leading: 32, bottom: 18, trailing: 32))
        .frame(width: 440, height: 370)
        .task {
            await preparation.value
            isPrepared = true
            if step == .preparing { step = .ready }
        }
        .task(id: step) {
            // The system reports no change, so look again while the user is away in System Settings.
            while step == .permission, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard step == .permission, ScreenPermission.isGranted else { continue }
                hasScreenAccess = true
                advance()
            }
        }
    }

    private var permissionPage: some View {
        Page {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
        } title: {
            Text("Welcome to TextCopy")
        } message: {
            Text("TextCopy copies text from anywhere on your screen. To read it, it needs your permission to see the screen. Everything stays on your Mac.")
            if didAskForAccess {
                Text("Turn on TextCopy in System Settings › Privacy & Security › Screen & System Audio Recording. If macOS asks to quit and reopen TextCopy, accept: setup continues from there.")
                    .font(.callout)
            }
        } actions: {
            Button(didAskForAccess ? "Open System Settings" : "Allow Screen Recording", action: askForAccess)
                .keyboardShortcut(.defaultAction)
            Button("Not Now", action: advance)
                .buttonStyle(.link)
        }
    }

    private var preparingPage: some View {
        Page {
            ProgressView()
                .controlSize(.large)
        } title: {
            Text("Getting ready to read text")
        } message: {
            Text("TextCopy is setting up text recognition on your Mac. It can take about a minute the first time, and you can keep using your Mac in the meantime.")
        } actions: {
            EmptyView()
        }
    }

    private var readyPage: some View {
        Page {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
        } title: {
            Text("You're all set")
        } message: {
            Text("Press \(shortcut.displayString) and drag over the text you want to copy. You'll find TextCopy in the menu bar.")
            if !hasScreenAccess {
                Text("Screen Recording is still off: TextCopy will ask for it again on your first capture.")
                    .font(.callout)
            }
        } actions: {
            Button("Done", action: onFinish)
                .keyboardShortcut(.defaultAction)
        }
    }

    /// The system prompts only once; after that the switch in System Settings is the only way.
    private func askForAccess() {
        if didAskForAccess {
            ScreenPermission.openSystemSettings()
        } else {
            ScreenPermission.request()
            didAskForAccess = true
        }
    }

    private func advance() {
        step = isPrepared ? .ready : .preparing
    }
}

/// One wizard page: artwork, title, message and buttons, with the buttons pinned to the bottom.
private struct Page<Artwork: View, Title: View, Message: View, Actions: View>: View {
    @ViewBuilder let artwork: Artwork
    @ViewBuilder let title: Title
    @ViewBuilder let message: Message
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 14) {
            artwork
                .frame(height: 80)
                .accessibilityHidden(true)
            title
                .font(.title2.bold())
            VStack(spacing: 10) { message }
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            VStack(spacing: 10) { actions }
                .controlSize(.large)
                .padding(.bottom, 18)
        }
    }
}
