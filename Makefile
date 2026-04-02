.PHONY: build test clean help icon check-translations screenshots

SCHEME = IoTPanels
PROJECT = IoTPanels/IoTPanels.xcodeproj
DESTINATION = 'platform=iOS Simulator,name=iPhone 17 Pro'
ICON_SOURCE = icon/App-Store-iOS.png
APPICONSET = IoTPanels/IoTPanels/Assets.xcassets/AppIcon.appiconset

help:
	@echo "Available targets:"
	@echo "  build  - Build for iOS Simulator"
	@echo "  test   - Run unit tests"
	@echo "  clean  - Clean build artifacts"
	@echo "  icon   - Generate app icon from icon/ exports"
	@echo "  check-translations - Check for missing translations"
	@echo "  screenshots        - Generate App Store screenshots (dark + light)"
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
