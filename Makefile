.PHONY: build test clean help icon

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
