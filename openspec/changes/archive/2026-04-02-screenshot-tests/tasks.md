## 1. App Support for UI Testing

- [x] 1.1 Add `--ui-testing` launch argument handling in `IoTPanelsApp` — auto-select demo home, install demo data
- [x] 1.2 Ensure demo home is created on first launch when `--ui-testing` is present

## 2. UI Test Target

- [x] 2.1 Create `IoTPanelsUITests` target in the Xcode project (done by user)
- [x] 2.2 Add `SnapshotHelper.swift` from fastlane to the UI test target
- [x] 2.3 Create `ScreenshotIds.swift` with semantic screenshot name constants
- [x] 2.4 Create `ScreenshotTests.swift` with `testDemoHomeScreenshots()` test method

## 3. Screenshot Test Flow

- [x] 3.1 Launch app with `--ui-testing` and `setupSnapshot(app)`
- [x] 3.2 Navigate to dashboard list → snapshot "Dashboards"
- [x] 3.3 Open Climate dashboard → wait for data → snapshot "Climate"
- [x] 3.4 Open Energy dashboard → snapshot "Energy"
- [x] 3.5 Open explorer from a panel → snapshot "Explorer"
- [x] 3.6 Navigate to Widget designer → snapshot "Widgets"
- [x] 3.7 Navigate to Data Sources → snapshot "Data Sources"
- [x] 3.8 Navigate to About → snapshot "About"

## 4. Fastlane Configuration

- [x] 4.1 Create `IoTPanels/fastlane/Snapfile` with device list, scheme, and test target config
- [x] 4.2 Create `IoTPanels/fastlane/devices.json` with target devices
- [x] 4.3 Create `IoTPanels/fastlane/Fastfile` with `screenshots` lane

## 5. Shell Scripts

- [x] 5.1 Create `scripts/prepare-screenshots.sh` — boot simulators, set appearance, override status bar
- [x] 5.2 Create `scripts/create-screenshots.sh` — loop dark/light, call prepare + fastlane, organize output

## 6. Makefile

- [x] 6.1 Add `screenshots` goal to existing Makefile

## 7. Testing

- [ ] 7.1 Run `make screenshots` and verify output in `./screenshots/{dark|light}/`
- [ ] 7.2 Verify screenshots cover all key screens with demo data visible
