## Why

IoT Panels currently ships for iPhone, iPad, and watchOS. A desk user with multiple data sources would benefit greatly from running IoT Panels on macOS, especially given the new adaptive layout (`flexible-dashboard-layout`) which already produces wider grids when more horizontal space is available. Mac Catalyst is explicitly off the table — the user wants a real native macOS app that uses native AppKit-backed SwiftUI rendering, native Mac controls, native window management, the standard Mac menu bar, native context menus, and ships as a true Mac app, not an iPad-in-a-window.

## What Changes

- Make the existing main app target multi-platform (`SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx`, `SDKROOT = auto`), so the same Xcode target builds a true native macOS app alongside the iOS one. **Not** Mac Catalyst.
- Same bundle identifier (`de.rnd7.iotpanels`) so Universal Purchase keeps working across iOS, iPadOS, and macOS.
- Add a new widget extension target specifically for macOS (`IoTPanelsMacWidgetExtension`), parallel to the existing iOS widget extension. WidgetKit is cross-platform at the API level but the extension bundle types differ.
- Audit every iOS-only SwiftUI API in the source and replace or `#if os(macOS)`-branch each one. Known offenders to address up front:
  - `.fullScreenCover` (iOS-only) — fall back to `.sheet` on macOS.
  - `.refreshable` and `.swipeActions` on `List` (iOS-only) — provide menu / context-menu equivalents on macOS.
  - `Color(uiColor: .secondarySystemGroupedBackground)` and similar `UIColor` system colors — use SwiftUI semantic colors that resolve on both platforms (or map per-platform via `#if`).
  - `UIBackgroundModes` and `BGTaskScheduler` plumbing — iOS-only; macOS doesn't need it for CloudKit sync.
  - `UIDocumentPicker`-style sheets — replace with `.fileImporter` / `.fileExporter` (already cross-platform; verify everywhere).
  - The single `UIColor(self)` reference in `Model/ColorUtilities.swift` — replace with `Color.resolve(in:)` so the file no longer reaches into UIKit.
- Rework the top-level navigation chrome for Mac. The iOS app uses a `TabView` (Dashboards / Widgets / Data Sources / About). On macOS this should render as a `NavigationSplitView` with a sidebar listing the same sections, plus a Mac-style toolbar. The existing iOS `TabView` stays for iPhone and iPad.
- Add a Mac-only `Settings` scene wired to the existing About / preferences content, accessible via the standard ⌘, shortcut.
- Add macOS App Sandbox + network-client + user-selected file read/write entitlements. Verify `iCloud.de.rnd7.iotpanels` and the `group.de.rnd7.iotpanels` App Group both work on macOS.
- Configure the Mac scene with sensible defaults: minimum window size, restorable state, and `windowResizability(.contentSize)`. Default to a window large enough to show 4-up small panels (iPad regular size class equivalent).
- Verify every existing data source backend (InfluxDB 1/2/3, Prometheus, MQTT via the user's CocoaMQTT fork — already supports macOS) builds and runs on Mac.
- Distribution: same App Store Connect record (Universal Purchase), separate macOS provisioning profile and certificate.

## Capabilities

### New Capabilities
- `macos-platform`: macOS as a first-class supported platform — a native multi-platform app target, native macOS chrome (sidebar, toolbar, menu bar, settings scene), all data source backends working on Mac, the widget extension running on Mac, iCloud sync between Mac and iOS, and Mac-specific entitlements.

### Modified Capabilities
None at the requirement level. Existing capabilities (`icloud-sync`, `dashboard-flow-layout`, `widget-data-caching`, `backup-restore`) keep their behavior; they gain a new platform.

## Impact

- Code: every SwiftUI view that uses an iOS-only modifier needs auditing. Expected files include `DashboardView.swift` (`.fullScreenCover`, `.refreshable`), `DashboardListView.swift`, `DataSourceListView.swift`, anything that uses `Color(uiColor: …)` or `Color(.secondarySystemGroupedBackground)`. The exact list is established in §1 of `tasks.md`.
- Project: `IoTPanels.xcodeproj/project.pbxproj` — change `SDKROOT`, `SUPPORTED_PLATFORMS`, `TARGETED_DEVICE_FAMILY` (add Mac), entitlements references, deployment target. Add a new macOS widget extension target.
- Entitlements: new macOS-specific keys (`com.apple.security.app-sandbox`, `com.apple.security.network.client`, `com.apple.security.files.user-selected.read-write`); existing iCloud + App Group entries are kept.
- Distribution: requires a Mac App Store provisioning profile and Mac signing certificate. App Review will run separately for the Mac binary.
- Risk: the iOS-only API audit may surface more files than expected, the navigation rework may need iteration to feel "Mac native", and the widget extension on macOS has a separate bundle layout that needs care.
