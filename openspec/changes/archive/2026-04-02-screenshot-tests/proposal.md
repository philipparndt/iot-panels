## Why

The app has no automated screenshots for the App Store listing or documentation. Creating screenshots manually is tedious, error-prone, and doesn't scale across devices and appearance modes. The sister project MQTT Analyzer has a proven pattern: XCUITests + fastlane + shell scripts that generate consistent screenshots across devices in both dark and light mode.

IoT Panels has a key advantage: the demo home provides realistic data without needing an external broker, making screenshots fully self-contained.

## What Changes

- Create a `IoTPanelsUITests` target with screenshot test(s) using the demo home
- Navigate through key screens: dashboards (Climate, Energy, Garden), data sources, widgets, explorer, about
- Use fastlane `capture_screenshots` with device configuration (iPhone Pro Max, iPhone Pro, iPad)
- Add shell scripts for screenshot automation: device prep, appearance switching, status bar override
- Add a `make screenshots` goal
- Generate screenshots in `./screenshots/{dark|light}/` directories

## Capabilities

### New Capabilities
- `screenshot-tests`: Automated UI tests that capture App Store screenshots using the demo home

### Modified Capabilities

## Impact

- **New**: `IoTPanelsUITests` target with `ScreenshotTests.swift`
- **New**: `fastlane/Snapfile`, `fastlane/devices.json`
- **New**: `scripts/create-screenshots.sh`, `scripts/prepare-screenshots.sh`
- **New**: `Makefile` with screenshots goal
- **App code**: May need `--ui-testing` launch argument to skip onboarding or auto-select demo home
- **Dependencies**: fastlane (brew install fastlane)
