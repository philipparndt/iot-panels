.PHONY: build test clean help icon check-translations screenshots screenshots-mac

SCHEME = IoTPanels
PROJECT = IoTPanels/IoTPanels.xcodeproj
DESTINATION = 'platform=iOS Simulator,name=iPhone 17 Pro'
ICON_SOURCE = icon/App-Store-iOS.png
APPICONSET = IoTPanels/IoTPanels/Assets.xcassets/AppIcon.appiconset
MAC_DERIVED_DATA = IoTPanels/build/DerivedData-macOS
APP_NAME = IoTPanels

help:
	@echo "Available targets:"
	@echo "  build              - Build for iOS Simulator"
	@echo "  test               - Run unit tests"
	@echo "  clean              - Clean build artifacts"
	@echo "  icon               - Generate app icon from icon/ exports"
	@echo "  check-translations - Check for missing translations"
	@echo "  screenshots        - Generate App Store screenshots (dark + light)"
	@echo "  screenshots-mac    - Build and launch macOS app sized for screenshots"
	@echo "  bump-major         - Bump major version (X.0.0)"
	@echo "  bump-minor         - Bump minor version (x.X.0)"
	@echo "  bump-patch         - Bump patch version (x.x.X)"

icon: $(APPICONSET)/AppIcon.png

$(APPICONSET)/AppIcon.png: $(ICON_SOURCE)
	cp $(ICON_SOURCE) $(APPICONSET)/AppIcon.png
	@echo "App icon updated."

build:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-configuration Debug

test:
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination $(DESTINATION)

clean:
	xcodebuild clean \
		-project $(PROJECT) \
		-scheme $(SCHEME)

check-translations:
	@python3 scripts/check-translations.py

bump-major:
	@python3 scripts/bump-version.py major

bump-minor:
	@python3 scripts/bump-version.py minor

bump-patch:
	@python3 scripts/bump-version.py patch

screenshots:
	./scripts/create-screenshots.sh

screenshots-mac:
	@echo "Building macOS app..."
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-configuration Debug \
		-derivedDataPath $(MAC_DERIVED_DATA) \
		-quiet
	@echo "Launching app..."
	@-killall $(APP_NAME) 2>/dev/null || true
	@sleep 0.5
	@open "$(MAC_DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app"
	@sleep 2
	@osascript \
		-e 'tell application "System Events" to tell process "$(APP_NAME)"' \
		-e '  set position of window 1 to {0, 0}' \
		-e '  set size of window 1 to {1200, 720}' \
		-e 'end tell'
	@echo "Window positioned at 0,0 with size 1200x720"
