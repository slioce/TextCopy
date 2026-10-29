APP := build/Build/Products/Release/TextCopy.app
BUNDLE_ID := com.alessandrolioce.TextCopy
XCODEBUILD := xcodebuild -project TextCopy.xcodeproj -scheme TextCopy -destination generic/platform=macOS -derivedDataPath build

.PHONY: build run install test icon archive reset-permission clean

# Release build, signed to run locally unless Config/Local.xcconfig sets a team.
build:
	@$(XCODEBUILD) -configuration Release build -quiet
	@echo "Built $(APP) ($$(du -sh $(APP) | cut -f1))"

run: build
	@pkill -x TextCopy || true
	@open $(APP)

install: build
	@pkill -x TextCopy || true
	@rm -rf /Applications/TextCopy.app
	@cp -R $(APP) /Applications/
	@open /Applications/TextCopy.app
	@echo "Installed /Applications/TextCopy.app"

test:
	@swift test --package-path TextCopyCore

icon:
	@swift scripts/make-icon.swift TextCopy/Resources/Assets.xcassets/AppIcon.appiconset

# App Store archive; needs DEVELOPMENT_TEAM in Config/Local.xcconfig. Upload from Xcode's Organizer.
archive:
	@$(XCODEBUILD) -configuration Release archive -archivePath build/TextCopy.xcarchive
	@open build/TextCopy.xcarchive

# Builds signed to run locally get a new signature each time, so macOS may ask for Screen Recording again.
reset-permission:
	@tccutil reset ScreenCapture $(BUNDLE_ID)

clean:
	@rm -rf build
