## Context

MQTT Analyzer uses a flow: `Makefile → shell script → fastlane → XCUITest → snapshot()`. Screenshots are generated per device and per appearance (dark/light) with overridden status bars. IoT Panels can use the same pattern but with the demo home instead of external MQTT messages.

## Goals / Non-Goals

**Goals:**
- Automated screenshots across iPhone and iPad devices
- Both dark and light mode variants
- Use demo home data (no external dependencies)
- Makefile goal for one-command generation
- Output organized as `./screenshots/{dark|light}/{Device}-{Name}.png`

**Non-Goals:**
- Localized screenshots (English only for now)
- Device framing (use external tools)
- Watch screenshots

## Decisions

### 1. Screenshot flow matching MQTT Analyzer

```
make screenshots
  → scripts/create-screenshots.sh
    → for each appearance (dark, light):
      → scripts/prepare-screenshots.sh (boot sims, set appearance, status bar)
      → fastlane screenshots (runs XCUITest)
      → move PNGs to ./screenshots/{appearance}/
```

### 2. UI test structure

Single test method `testDemoHomeScreenshots()` that:
1. Launches app with `--ui-testing` flag
2. Ensures demo home is selected
3. Navigates to each screen and calls `snapshot(name)`

Screens to capture:
- Dashboard list (shows Climate, Energy, Garden)
- Climate dashboard (charts with live demo data)
- Energy dashboard
- Data sources list
- Widget designer
- Chart explorer (opened from a panel)
- About page

### 3. Launch argument `--ui-testing`

When present:
- Auto-select demo home if multiple homes exist
- Disable any onboarding/welcome screens
- Disable animations for faster test execution

### 4. SnapshotHelper.swift from fastlane

Use the standard fastlane `SnapshotHelper.swift` which provides the `snapshot()` function and handles simulator detection, screenshot saving, and waiting for loading indicators.

### 5. Device configuration

Target devices (matching App Store requirements):
- iPhone 16 Pro Max (6.9")
- iPhone 16 Pro (6.3")
- iPad Air 13-inch (M3)
