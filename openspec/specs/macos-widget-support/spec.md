# macos-widget-support Specification

## Purpose
TBD - created by archiving change macos-widget-support. Update Purpose after archive.
## Requirements
### Requirement: Widget extension builds and embeds for macOS
The `IoTPanelsWidgetExtension` SHALL build successfully when targeting the macOS platform and SHALL be embedded in the macOS application bundle under `Contents/PlugIns/` in App Store archives.

#### Scenario: macOS archive contains the widget extension
- **WHEN** `xcodebuild archive -scheme IoTPanels -destination 'generic/platform=macOS'` is run
- **THEN** the resulting `IoTPanels.app/Contents/PlugIns/IoTPanelsWidgetExtension.appex` exists and has a non-empty Mach-O executable

#### Scenario: iOS build unaffected
- **WHEN** `xcodebuild archive -scheme IoTPanels -destination 'generic/platform=iOS'` is run
- **THEN** the resulting `.ipa` contains `IoTPanelsWidgetExtension.appex` with the same widget families as before this change

### Requirement: Widget extension passes Mac App Store validation
The macOS widget extension SHALL satisfy Apple's App Store binary validation rules so that App Store Connect uploads are accepted without ITMS-90296 or ITMS-90896 errors.

#### Scenario: Sandbox entitlement present
- **WHEN** the macOS widget extension binary is inspected via `codesign -d --entitlements`
- **THEN** it declares `com.apple.security.app-sandbox` with a boolean value of true

#### Scenario: Swift entry section present
- **WHEN** `otool -l` is run against the embedded widget extension's Mach-O binary in the macOS archive
- **THEN** a `__swift5_entry` section is present

#### Scenario: Upload to App Store Connect
- **WHEN** a macOS build containing the widget extension is uploaded to App Store Connect
- **THEN** the upload completes without ITMS-90296 or ITMS-90896 errors

### Requirement: Widgets appear in the macOS widget gallery
All widget families registered by `IoTPanelsWidgetBundle` SHALL be available in the macOS widget gallery with the same display name, description, and supported sizes as on iOS.

#### Scenario: Widget gallery listing
- **WHEN** a user opens the macOS widget gallery and searches for "IoT Panels"
- **THEN** the panel widget, single-value widget, countdown widget, and transparent countdown widget all appear

#### Scenario: Supported sizes
- **WHEN** a user selects the IoT Panels panel widget in the macOS widget gallery
- **THEN** `systemSmall`, `systemMedium`, and `systemLarge` sizes are offered

### Requirement: Widget data parity with iOS
Widgets running on macOS SHALL display the same data, refresh on the same schedule, and honor the same configuration intents as on iOS.

#### Scenario: Widget design selection
- **WHEN** a user configures a panel widget on macOS and picks a widget design via `SelectWidgetDesignIntent`
- **THEN** the widget renders the selected design using data loaded through `WidgetDataLoader` from the shared app group container

#### Scenario: Timeline refresh
- **WHEN** a configured widget's refresh interval elapses on macOS
- **THEN** the widget re-runs its timeline provider and updates the displayed values

#### Scenario: Empty state
- **WHEN** a widget is placed on macOS before any widget design is configured
- **THEN** the widget displays the same empty-state view as iOS

### Requirement: Cross-platform widget rendering
The widget code SHALL render correctly on both iOS and macOS without relying on UIKit-only APIs at widget build time.

#### Scenario: No UIKit imports in widget target on macOS
- **WHEN** the widget extension compiles for the macOS SDK
- **THEN** no compilation errors occur from `UIColor`, `UIImage`, or other UIKit-only types

#### Scenario: Adaptive background
- **WHEN** a widget design specifies the "adaptive" background color on macOS
- **THEN** the widget uses the system's default widget container background instead of a hard-coded color
