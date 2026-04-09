## ADDED Requirements

### Requirement: IoT Panels runs as a native macOS app
The system SHALL build and run as a true native macOS application from the same Xcode target as the iOS app, using the macOS SDK directly. The Mac binary SHALL NOT use Mac Catalyst.

#### Scenario: Mac build uses macOS SDK
- **WHEN** the developer builds the main app target for the "My Mac" destination
- **THEN** the build uses the macOS SDK (not Mac Catalyst), the resulting `.app` is an arm64 / x86_64 macOS binary, and `otool -L` shows it links AppKit (not `MacCatalyst.framework`)

#### Scenario: Universal Purchase across iOS, iPadOS, and macOS
- **WHEN** a user has installed the iOS app and opens the Mac App Store on a Mac signed in with the same Apple ID
- **THEN** the macOS version is shown as already owned and downloads as part of the same purchase, because both binaries share the bundle identifier `de.rnd7.iotpanels`

### Requirement: macOS uses native sidebar navigation, not iOS-style tabs
The system SHALL render its top-level navigation on macOS as a `NavigationSplitView` with a sidebar listing the same sections (Dashboards, Widgets, Data Sources, About) that the iOS app surfaces in its `TabView`. The iOS app SHALL keep its existing `TabView`.

#### Scenario: Mac shows sidebar
- **WHEN** the Mac app launches
- **THEN** the main window shows a sidebar on the left with Dashboards, Widgets, Data Sources, and About entries

#### Scenario: Sidebar selection swaps the detail pane
- **WHEN** the user clicks "Widgets" in the Mac sidebar
- **THEN** the detail pane shows the widget designs list — the same SwiftUI view that iOS shows under its Widgets tab

#### Scenario: iOS unaffected
- **WHEN** the iOS app launches
- **THEN** it still shows the existing bottom `TabView` with the same four sections

### Requirement: Mac surfaces a Settings scene under the standard app menu
The system SHALL provide a macOS `Settings` scene accessible via the standard "IoT Panels → Settings…" menu item (⌘,) that contains the project's preferences UI (initially mapped to the existing About content).

#### Scenario: Settings menu item is present
- **WHEN** the user clicks the IoT Panels application menu on macOS
- **THEN** "Settings…" is listed and is enabled

#### Scenario: ⌘, opens Settings
- **WHEN** the user presses ⌘,
- **THEN** the Settings window opens

### Requirement: Core data source backends work on macOS
The system SHALL connect to InfluxDB (1, 2, 3), Prometheus, and MQTT data sources from the Mac build, using the same `DataSourceServiceProtocol` implementations as iOS.

#### Scenario: InfluxDB query on Mac
- **WHEN** the user adds an InfluxDB 2 data source on the Mac build and opens a dashboard backed by it
- **THEN** the dashboard shows live data, identical to the iOS behavior

#### Scenario: MQTT broker on Mac
- **WHEN** the user connects to an MQTT broker via the Mac build
- **THEN** subscriptions deliver messages and panels update, identical to iOS

#### Scenario: Demo home on Mac
- **WHEN** the user creates a demo home on the Mac build
- **THEN** all demo dashboards (Climate, Energy, Garden, Node Exporter) render with synthesized data, including the adaptive Node Exporter layout

### Requirement: iCloud sync works between Mac and iOS
The system SHALL synchronize all user data (homes, dashboards, data sources, saved queries, widget designs) between the Mac build and iOS builds via the existing CloudKit container `iCloud.de.rnd7.iotpanels`, with no schema or container changes.

#### Scenario: iOS-to-Mac sync
- **WHEN** the user creates a dashboard on iPhone
- **THEN** the Mac build (signed into the same Apple ID) shows the new dashboard within a reasonable window

#### Scenario: Mac-to-iOS sync
- **WHEN** the user creates a dashboard on Mac
- **THEN** the iPhone build shows it after CloudKit propagates the change

### Requirement: macOS entitlements support sandboxed network and file access
The system SHALL ship with App Sandbox enabled, the network-client entitlement granted, and the user-selected files read/write entitlement granted, so outbound HTTP / TCP requests to user-configured data sources work and so backup import / export works under Mac App Store distribution rules.

#### Scenario: Sandboxed network call
- **WHEN** the Mac build (sandboxed) issues an outbound HTTPS request to a Prometheus endpoint
- **THEN** the request succeeds — i.e. the network-client entitlement is granted

#### Scenario: Sandboxed file save
- **WHEN** the Mac user picks a destination via the system save panel and exports a backup
- **THEN** the file is written successfully — i.e. the user-selected files entitlement is granted

#### Scenario: No server entitlement
- **WHEN** the Mac entitlements file is inspected
- **THEN** `com.apple.security.network.server` is NOT present

### Requirement: Source compiles cleanly on macOS
The system's main app source SHALL compile against the macOS SDK without unguarded references to UIKit-only types (`UIColor`, `UIScreen`, `UIDevice`, `UIPasteboard`, `UIImage`, `import UIKit`). Where iOS-only SwiftUI modifiers are used (`fullScreenCover`, `refreshable`, `swipeActions`), the call site SHALL provide a macOS-equivalent code path inside `#if os(iOS)` / `#if os(macOS)` branches.

#### Scenario: Color utilities are SwiftUI-only
- **WHEN** `Model/ColorUtilities.swift` is built for macOS
- **THEN** the file does not reference `UIColor` and produces the same hex output as the iOS build

#### Scenario: No latent UIKit imports
- **WHEN** the entire main-app source tree is grepped for `import UIKit` outside `#if canImport(UIKit)` guards
- **THEN** no matches are found

#### Scenario: fullScreenCover has a macOS fallback
- **WHEN** the chart explorer is opened on macOS (the iOS code uses `.fullScreenCover`)
- **THEN** an equivalent presentation appears on macOS via `.sheet`

### Requirement: Adaptive dashboard layout uses the wide-window benefit on Mac
The system SHALL render dashboards on Mac using the regular horizontal size class so that `small` panel slots resolve to ¼ width and `medium` slots resolve to ½ width on the default Mac window. Resizing the window SHALL re-flow panels via the existing `PanelFlowLayout` without restart.

#### Scenario: Wide Mac window shows iPad-class layout
- **WHEN** the Mac build opens the Node Exporter dashboard at the default window size
- **THEN** the small gauges appear 4-up on a single row and the medium charts pair up below

#### Scenario: Window resize re-flows panels
- **WHEN** the user shrinks the Mac window below the regular size-class threshold
- **THEN** the dashboard re-flows to the compact layout (2-up small, 1-up medium) without an app restart

#### Scenario: Default window size is sensible
- **WHEN** the Mac app launches for the first time
- **THEN** the main window opens at a size large enough for the iPad-class layout (default 1280×800 or larger)

### Requirement: Widget extension runs on macOS via a separate extension target
The system SHALL include a macOS widget extension target that reuses the iOS widget Swift source files. The same widget designs SHALL render in macOS Notification Center, reading the same App Group store as the main app.

#### Scenario: Mac widget target builds
- **WHEN** the developer builds the macOS widget extension target
- **THEN** the build succeeds

#### Scenario: Mac widget renders the same design
- **WHEN** the user adds the IoT Panels widget to macOS Notification Center
- **THEN** it shows the same widget design as the iPhone counterpart for the same `WidgetDesign` record

### Requirement: Backup import / export works on macOS
The system SHALL allow the Mac user to export a JSON backup file via the system save panel and to restore from a JSON backup via the system open panel, using the existing `BackupService` code path through SwiftUI's `.fileExporter` / `.fileImporter`.

#### Scenario: Export on Mac
- **WHEN** the Mac user taps "Backup" in the Settings or About screen
- **THEN** a system save panel opens and the JSON file is written to the chosen location

#### Scenario: Restore on Mac
- **WHEN** the Mac user taps "Restore" and selects a backup file
- **THEN** the data is imported and reflected on screen, identical to iOS behavior

### Requirement: Distribution via Universal Purchase
The system SHALL ship under the same App Store Connect record as the iOS app, with the same bundle identifier `de.rnd7.iotpanels`, so that Universal Purchase applies and Mac users do not pay separately if they already own the iOS app.

#### Scenario: Same bundle identifier
- **WHEN** the Mac binary is inspected
- **THEN** its `CFBundleIdentifier` is `de.rnd7.iotpanels`, identical to the iOS binary

#### Scenario: Single App Store Connect record
- **WHEN** the developer prepares the Mac release in App Store Connect
- **THEN** the Mac binary is added to the existing iOS app record (Universal Purchase), not a new app record
