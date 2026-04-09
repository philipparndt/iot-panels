## Why

IoT Panels now ships as a native macOS app, but the WidgetKit extension is excluded from the macOS build (all widget source files are wrapped in `#if !os(macOS)` and the extension is stripped from the macOS archive). macOS users cannot place IoT Panels widgets in Notification Center, on the desktop, or in Control Center, losing feature parity with iOS/iPadOS.

## What Changes

- Build and embed `IoTPanelsWidgetExtension` for the macOS platform in addition to iOS/iPadOS.
- Remove the `#if !os(macOS)` gates from the widget sources and replace iOS-only APIs (e.g., `UIColor.systemBackground`) with cross-platform equivalents.
- Add the `com.apple.security.app-sandbox` entitlement to the widget extension so it passes Mac App Store validation (ITMS-90296).
- Ensure the widget extension produces a valid macOS Mach-O binary with a `__swift5_entry` section (fixing ITMS-90896 when the extension is embedded on macOS).
- Declare macOS as a supported widget family target and make the widget bundle available in the macOS widget gallery.

## Capabilities

### New Capabilities
- `macos-widget-support`: Running the IoT Panels WidgetKit extension on macOS, including desktop/Notification Center widgets, cross-platform rendering, and Mac App Store packaging requirements for the extension.

### Modified Capabilities
<!-- None. Existing widget capabilities (widget-grid-layout, widget-chart-types, etc.)
     describe behavior that already applies across platforms; no requirement-level
     changes are needed. This change only makes that existing behavior available on macOS. -->

## Impact

- `IoTPanels/IoTPanelsWidget/*.swift`: remove `#if !os(macOS)` gates; replace `Color(uiColor: .systemBackground)` and any other UIKit-only calls with SwiftUI or AppKit-compatible equivalents.
- `IoTPanels/IoTPanelsWidget/IoTPanelsWidget.entitlements`: add `com.apple.security.app-sandbox` = true.
- `IoTPanels/IoTPanels.xcodeproj/project.pbxproj`:
  - Re-add `macosx` to the widget extension's `SUPPORTED_PLATFORMS`.
  - Remove the `platformFilter = ios` from the widget embed build file and target dependency so the extension is embedded on macOS too.
  - Ensure `ENABLE_APP_SANDBOX = YES` and a macOS deployment target are set on the widget extension.
- Shared widget code paths (`WidgetDataLoader`, `PanelRenderer`, `WidgetDesign+Wrapped`) need auditing for UIKit-only APIs.
- Mac App Store delivery: unblocks the 1.3.x macOS submission by delivering a valid widget extension instead of hitting ITMS-90296 / ITMS-90896.
