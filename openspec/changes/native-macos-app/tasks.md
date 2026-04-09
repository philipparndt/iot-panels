## 1. Audit — find every iOS-only API in the source

- [x] 1.1 Grep the main app source for `import UIKit`, `UIColor`, `UIScreen`, `UIDevice`, `UIPasteboard`, `UIImage`, `UIApplication`. Record every match.
- [x] 1.2 Grep for iOS-only SwiftUI modifiers: `fullScreenCover`, `\.refreshable`, `swipeActions`, `Color\(uiColor:`, `Color\(\.system`, `secondarySystemGroupedBackground`, `secondarySystemBackground`, `tertiarySystemBackground`. Record every match.
- [x] 1.3 Grep for `UIDocumentPicker`, `UTType`, `.fileImporter`, `.fileExporter` to verify all file pickers are already cross-platform
- [x] 1.4 Produce a single audit document listing each finding with file:line and the planned macOS replacement strategy (per-call branch vs. SwiftUI semantic color vs. SwiftUI-only API)

## 2. Drop UIKit dependency from `ColorUtilities`

- [x] 2.1 Replace `UIColor(self)` in `Model/ColorUtilities.swift:32` with `Color.resolve(in:)` (iOS 17+/macOS 14+) or an equivalent SwiftUI-only path
- [ ] 2.2 Build the iOS target — must compile and produce identical hex output for the same `Color` *(requires user to run xcodebuild / Xcode)*
- [x] 2.3 Add a unit test if one does not exist for the hex round-trip, covering at least 5 representative colors

## 3. Project configuration — multi-platform target

- [ ] 3.1 In `IoTPanels.xcodeproj/project.pbxproj`, change `SDKROOT` from `iphoneos` to `auto` for the main app target (Debug + Release)
- [ ] 3.2 Change `SUPPORTED_PLATFORMS` from `"iphoneos iphonesimulator"` to `"iphoneos iphonesimulator macosx"`
- [ ] 3.3 Update `TARGETED_DEVICE_FAMILY` from `"1,2"` to `"1,2,6"` so Mac is a valid device family
- [ ] 3.4 Set the macOS deployment target (likely `MACOSX_DEPLOYMENT_TARGET = 14.0`)
- [ ] 3.5 Verify `SUPPORTS_MACCATALYST = NO` is preserved (we are explicitly NOT using Catalyst)
- [ ] 3.6 Add a "My Mac" destination to the IoTPanels scheme so it's runnable from the destination picker

## 4. Entitlements — macOS

- [ ] 4.1 Decide whether to extend `IoTPanels.entitlements` with platform-conditional keys or to add a separate `IoTPanels-macOS.entitlements` file. Recommendation: separate file referenced via `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`
- [ ] 4.2 Add `com.apple.security.app-sandbox = YES` for the macOS entitlements
- [ ] 4.3 Add `com.apple.security.network.client = YES`
- [ ] 4.4 Add `com.apple.security.files.user-selected.read-write = YES`
- [ ] 4.5 Carry over `com.apple.developer.icloud-container-identifiers`, `com.apple.developer.icloud-services`, and `com.apple.security.application-groups` from the iOS entitlements
- [ ] 4.6 Confirm `com.apple.security.network.server` is NOT present

## 5. First Mac build — fix what surfaces

- [~] 5.1 Build the main app target for "My Mac" Debug *(in progress — user iterating)*
- [x] 5.2 Triage compile errors by file. For each iOS-only API found in §1, apply the planned replacement *(proactive pass — may need further fixes after build)*
- [ ] 5.3 Build for Release configuration as well
- [ ] 5.4 Capture all platform branches into a single commit so the diff is reviewable as "macOS audit fixes"

## 6. Mac chrome — sidebar navigation root view

- [x] 6.1 Create `Views/MacRootView.swift` containing a `NavigationSplitView` with a sidebar listing Dashboards, Widgets, Data Sources, About
- [x] 6.2 Each sidebar item presents the same SwiftUI view that the iOS `TabView` shows for that tab
- [x] 6.3 Update `IoTPanelsApp.swift` to switch the root view by `#if os(macOS) … MacRootView() … #else … ContentView() … #endif`
- [x] 6.4 Apply Mac-specific scene modifiers: `.windowResizability(.contentSize)`, `.defaultSize(width: 1280, height: 800)`
- [ ] 6.5 Confirm the iOS app still launches into its `TabView` unchanged *(needs user build verification)*

## 7. Settings scene

- [x] 7.1 Add a `Settings { ... }` scene declaration to `IoTPanelsApp.swift` inside `#if os(macOS)`
- [x] 7.2 Decide whether the Settings scene wraps `AboutView` directly or extracts a `MacSettingsView` (recommended: extract if About contains version info that doesn't belong in Settings) *(wraps AboutView directly for v1; extract later if needed)*
- [ ] 7.3 Verify ⌘, opens the Settings window *(needs user build verification)*
- [ ] 7.4 Verify the IoT Panels application menu lists "Settings…" as enabled *(needs user build verification)*

## 8. macOS widget extension

- [ ] 8.1 Create a new target `IoTPanelsMacWidgetExtension` of type "Widget Extension" with deployment target macOS 14
- [ ] 8.2 Add the iOS widget extension's Swift source files to the new target's "Compile Sources" phase by reference (NOT by copying)
- [ ] 8.3 Configure the new target's `Info.plist` with `NSExtension.NSExtensionPointIdentifier = "com.apple.widgetkit-extension"` and the same App Group as iOS
- [ ] 8.4 Configure the new target's entitlements with App Sandbox, App Group, and iCloud container references
- [ ] 8.5 Build the new target. Triage any iOS-only widget code via `#if os(macOS)` branches inside the shared widget files
- [ ] 8.6 Add the new extension as a dependency of the main app target so it's bundled in the Mac `.app`

## 9. Smoke testing — Mac runtime

- [ ] 9.1 Launch the Mac build. Verify the sidebar appears and selecting Dashboards shows the dashboard list
- [ ] 9.2 Create a demo home and open the Node Exporter dashboard. Confirm 4-up small gauges + 2-up medium charts at the default window size
- [ ] 9.3 Resize the window narrow. Confirm the dashboard re-flows to compact 2-up layout
- [ ] 9.4 Tap the "Adaptive layout · iPad view" chip. Verify the popover appears with the correct mapping
- [ ] 9.5 Add a real InfluxDB or Prometheus data source. Confirm queries return data
- [ ] 9.6 Connect to an MQTT broker. Confirm subscriptions and panel updates
- [ ] 9.7 Sign in to iCloud on the Mac. Verify a dashboard created on iPhone appears on Mac and vice versa
- [ ] 9.8 Test backup export — system save panel opens, file written
- [ ] 9.9 Test backup restore — system open panel opens, data imports
- [ ] 9.10 Open the Settings menu (⌘,) — verify the window appears
- [ ] 9.11 Verify the Mac context menus on dashboard panels match the iOS ones (Layout submenu, Display Style, Edit Panel, etc.)

## 10. Widget on macOS

- [ ] 10.1 Add the IoT Panels widget to macOS Notification Center
- [ ] 10.2 Confirm it renders the same widget design as the iPhone counterpart, reading from the App Group store
- [ ] 10.3 If the widget renders incorrectly on Mac (font weights, spacing, colors), apply minimal `#if os(macOS)` adjustments inside the shared widget files

## 11. Distribution

- [ ] 11.1 Add a Mac record in App Store Connect linked to the existing iOS record (Universal Purchase)
- [ ] 11.2 Generate the Mac App Store provisioning profile and Mac signing certificate
- [ ] 11.3 Archive a native macOS build (not Catalyst) and upload to TestFlight
- [ ] 11.4 Install via TestFlight on a clean Mac and re-run the smoke tests from §9

## 12. Documentation

- [ ] 12.1 Update `Docs/README.md` to mention native macOS support
- [ ] 12.2 Update `Docs/privacy-policy.md` if any Mac-specific data handling note is required
- [ ] 12.3 Add a release-notes entry for the Mac launch
