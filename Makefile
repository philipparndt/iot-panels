.PHONY: build test clean help

SCHEME = IoTPanels
PROJECT = IoTPanels/IoTPanels.xcodeproj
DESTINATION = 'platform=iOS Simulator,name=iPhone 17 Pro'

help:
	@echo "Available targets:"
	@echo "  build  - Build for iOS Simulator"
	@echo "  test   - Run unit tests"
	@echo "  clean  - Clean build artifacts"

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
