# TextCopy

A menu bar app for macOS that copies text from anywhere on your screen. Press the shortcut, select an area, and the recognized text is on your clipboard. If the area contains a QR code or a barcode, its content is copied instead.

## Features

- **On-device OCR** with Apple's Vision framework. Nothing leaves your Mac, and there are no third-party dependencies.
- **System area selection**, the same crosshair as a screenshot: press Space to pick a whole window, Esc to cancel.
- **QR codes and barcodes**: their content is copied, and web links can optionally be opened right away.
- **Clear confirmation**: a floating "Copied" panel with a preview of the text, a checkmark in the menu bar and a sound.
- **Recognition settings**: automatic language detection or a fixed language; language correction can be turned off to copy code, links and serial numbers exactly as they appear.
- **Customizable global shortcut** (default ⇧⌘2) and launch at login.
- Localized in English and Italian.
- Sandboxed, about 1 MB, no network access.

## Requirements

macOS 15 or later, on Apple Silicon or Intel.

## Usage

1. Press ⇧⌘2 (or click the menu bar icon and choose **Capture Text**).
2. Drag over the text you want. Press Space to switch to window selection, Esc to cancel.
3. The text is on your clipboard; paste it anywhere.

Open **Settings…** from the menu bar icon to change the shortcut, the recognition language, the sound and launch at login.

> If another app already uses ⇧⌘2, choose a different shortcut in TextCopy's settings.

## Permissions

On the first capture, macOS asks for **Screen Recording** permission; TextCopy needs it to see the area you select. You can also grant it later in System Settings › Privacy & Security › Screen & System Audio Recording.

Builds signed to run locally get a new signature on each build, so macOS may ask again after you rebuild. `make reset-permission` clears the stored decision.

## Build from source

Requires Xcode 16 or later.

```sh
git clone https://github.com/slioce/TextCopy.git
cd TextCopy
make install   # builds, copies to /Applications and launches
make run       # launches the build without installing it
make test      # runs the OCR engine tests
```

Or open `TextCopy.xcodeproj` in Xcode and press Run. The project is signed to run locally out of the box; no developer account is needed.

On its first launch, TextCopy compiles Vision's models in the background, once (about a minute). Captures then take a fraction of a second.

## Project layout

```
TextCopy/              The app: menu bar item, capture flow, HUD, hotkey, settings.
TextCopy/Resources/    Info.plist, entitlements, privacy manifest, icon, localizations.
TextCopyCore/          Swift package with the OCR engine and its tests. No AppKit, no UI.
Config/                Build settings shared by every configuration (xcconfig).
scripts/               make-icon.swift draws the app icon set.
```

The engine is a single call: `TextRecognizer().recognize(image)` returns `.text`, `.barcodes` or `.empty`. Barcodes win over text, because a selection around a QR code is almost always about its content.

## Publishing to the App Store

1. Create `Config/Local.xcconfig` (ignored by git) with your team:

   ```
   DEVELOPMENT_TEAM = ABCDE12345
   CODE_SIGN_IDENTITY = Apple Development
   ```

2. In Xcode, choose Product › Archive (or run `make archive`), then Distribute App › App Store Connect.

The app runs in the App Sandbox. Area selection uses the system's own `screencapture -i`, whose picker registers the Mach service `com.apple.screencapture.interactive`; the sandbox blocks that unless the app declares a `com.apple.security.temporary-exception.mach-register.global-name` entitlement for it. Mention this in the App Review notes, for example:

> The app launches the system `screencapture -i` tool so the user can select a screen area with the standard macOS picker. The `mach-register.global-name` temporary exception for `com.apple.screencapture.interactive` is required for that picker to appear inside the sandbox. The app has no network access and all text recognition happens on device with Vision.

## Privacy

Everything happens on your Mac. TextCopy has no network access, collects no data, and keeps nothing but its settings. The privacy manifest (`PrivacyInfo.xcprivacy`) declares no tracking and no collected data.

## Acknowledgements

TextCopy is inspired by [TextSniper](https://textsniper.app). It was written with the help of AI coding agents; design, review and testing are the author's.

## License

Copyright © 2026 Alessandro Lioce. TextCopy is free software, released under the [GNU General Public License v3.0](LICENSE) or any later version.
