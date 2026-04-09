## Context

IoT Panels is a SwiftUI app currently targeting iOS / iPadOS / watchOS. The Xcode project is set up with one main app target, one iOS widget extension, one watchOS app, one watchOS widget extension, and the test targets. The project's main app target has `SUPPORTS_MACCATALYST = NO` set explicitly — Mac Catalyst is off — and `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`. The user has rejected Mac Catalyst and wants a true native macOS app: AppKit-backed SwiftUI rendering, native menu bar, native sidebar, native cursor, native window management.

A code audit shows the main app source is overwhelmingly portable SwiftUI:

- Exactly one direct UIKit reference: `UIColor(self)` in `Model/ColorUtilities.swift:32`.
- Exactly one explicit platform check: `#if os(watchOS)` in `PanelCardView.swift:21`.
- All view code uses SwiftUI types (`Form`, `List`, `NavigationStack`, `TabView`, `Menu`, `Picker`, `Chart`, etc.).
- No `UIViewRepresentable` / `UIViewControllerRepresentable` bridges in the main flows.
- No use of Apple-private iOS frameworks.

The areas that *do* differ between iOS and macOS in modern SwiftUI are:

1. **Navigation idiom.** `TabView` works on macOS but renders as a segmented control or flat tabs that don't feel Mac-native. The Mac convention for an app with several top-level sections is `NavigationSplitView` with a sidebar.
2. **iOS-only modifiers.** `.fullScreenCover`, `.refreshable` (on List), `.swipeActions` (on List), and a few others are not available on macOS or have different semantics.
3. **System colors.** `Color(uiColor: .secondarySystemGroupedBackground)` and similar UIKit-system-color expressions don't compile on macOS without UIKit. The portable replacement is a SwiftUI semantic color (`.background`, `.secondary`, `Color(.windowBackgroundColor)` via NSColor) or a per-platform branch.
4. **Background tasks.** iOS uses `BGTaskScheduler` (and the `processing` `UIBackgroundModes` key) for `NSPersistentCloudKitContainer` exports. macOS doesn't need this — Mac apps run as long as they're open, and CloudKit sync happens via remote-change notifications.
5. **Document picking.** SwiftUI's `.fileImporter` / `.fileExporter` are cross-platform and should be used uniformly. Confirm the existing flow uses them rather than `UIDocumentPicker`.
6. **Widget extensions.** WidgetKit at the API level is cross-platform, but extension bundles are per-platform: a macOS widget must live in a macOS extension target. The shared widget Swift code can be linked from both.
7. **Settings scene.** macOS apps use a `Settings` scene exposed via the standard ⌘, menu item; iOS doesn't.

There is also one ongoing platform-relevant constraint from a previous change: the iOS app needs `processing` in `UIBackgroundModes` for CloudKit sync to actually run. That key is iOS-only (`Info.plist` is shared, but the key is ignored on macOS). No conflict.

## Goals / Non-Goals

**Goals:**
- A Mac build that opens, renders, and syncs identically to the iOS build, but with a Mac-native UI shell (sidebar navigation, native menu bar, native context menus, native cursor, native window).
- Zero Catalyst. The Mac binary runs against the macOS SDK directly and uses pure SwiftUI / AppKit-backed primitives.
- Universal Purchase. Same bundle ID, same App Store Connect record, no extra purchase for Mac users who already own the iOS app.
- Maintain the iOS app exactly as it is. The Mac work is additive: every iOS code path is preserved unchanged.
- Reuse view code wherever it's portable; only branch with `#if os(macOS)` where the Mac affordance genuinely differs.
- The macOS widget extension uses the same widget design code as iOS, so designs sync via CloudKit and look the same on every device.

**Non-Goals:**
- Mac Catalyst, in any form.
- A from-scratch AppKit rewrite. SwiftUI is the primary UI framework on both platforms.
- Multi-window scene management (`WindowGroup` with multiple windows). One main window is enough for v1; users can have multiple if they want, but no special inter-window state.
- Touch Bar.
- Menu bar / status item app.
- A separate Mac-specific design language. The Mac UI follows the same dashboard / panels structure as iOS.

## Decisions

### D1: Single multi-platform target, not a separate Mac target

Modify the existing `IoTPanels` Xcode target so that it builds for both `iphoneos` and `macosx` (and `iphonesimulator` for development). `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"`, `SDKROOT = auto`, `TARGETED_DEVICE_FAMILY = "1,2,6"` (the `6` is Mac).

This is **not** Mac Catalyst. Catalyst is a UIKit shim that runs the iOS UIKit on macOS via `MacCatalyst.framework`. A multi-platform SwiftUI target with `macosx` support compiles the source against the macOS SDK directly and links AppKit under the hood — that's a true native Mac binary.

**Why:**
- One target = one source list = no manual file membership management.
- One bundle ID + one App Store Connect record + Universal Purchase.
- The view code is already SwiftUI, which is the only UI framework that supports both compile paths.
- Lower long-term maintenance: every iOS feature gets the Mac platform automatically.

**Alternatives considered:**

- *Separate `IoTPanelsMac` target.* Would require explicit per-target file membership, two `Info.plist`s, two entitlements files, two scheme management. Net negative for an app whose Swift sources are 99% portable.
- *Local Swift package for shared sources, two thin app targets.* The cleanest separation in theory, but moving the existing source into a package is significant churn for a project that's already organized by feature folders. Defer until / unless the Mac code diverges enough to justify it.

### D2: Navigation rewrites top-level chrome for Mac, but reuses every leaf view

The iOS app uses `TabView` at the top level. On macOS we use `NavigationSplitView` with a sidebar listing the same four sections (Dashboards, Widgets, Data Sources, About). The detail panes are exactly the same SwiftUI views that iOS shows in its tab content. Only the top-level container changes; everything below is shared.

```swift
@main
struct IoTPanelsApp: App {
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            MacRootView()
            #else
            ContentView()
            #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 1280, height: 800)

        Settings {
            AboutView() // or a Mac-specific Settings view that wraps About
        }
        #endif
    }
}
```

`MacRootView` is the new file that contains the `NavigationSplitView` shell. It is a thin wrapper. Every interior view (`DashboardListView`, `DashboardView`, `PanelCardView`, etc.) is reused unchanged.

**Why:** Mac users expect a sidebar-based app for multi-section apps. A `TabView` at the top of a Mac window is a tell that the app is iOS-first. Splitting the chrome out to a Mac-specific root view is a small, contained file that preserves all leaf views.

### D3: Branch iOS-only SwiftUI APIs at the call site, not the framework boundary

Each iOS-only modifier gets a small `#if os(iOS)` / `#else` branch directly where it's used. We do not introduce wrapper "shim" views. Targeted branches in five or so places are easier to read than a parallel SwiftUI shim layer.

The audit list:

| API | iOS use | macOS replacement |
|---|---|---|
| `.fullScreenCover` | ChartExplorerView modal | `.sheet` |
| `.refreshable` on List | dashboard pull-to-refresh | Toolbar refresh button (already exists for menu) |
| `.swipeActions` on List | row delete | Context menu Delete (which already exists in this codebase) |
| `Color(uiColor: .secondarySystemGroupedBackground)` | panel card background | `Color(NSColor.controlBackgroundColor)` on macOS |
| `UIColor(self)` | hex extraction | `Color.resolve(in:)` (cross-platform) |
| `UIBackgroundModes.processing` | iOS CloudKit sync | not needed on macOS (Info.plist key is silently ignored) |

**Why:** The branches are small and local. A wrapper view would add a layer of indirection for ~6 modifiers across the whole app.

### D4: Separate macOS widget extension target, sharing widget Swift sources

WidgetKit `Widget` and `TimelineProvider` types are cross-platform Swift types, but the *bundle* of a widget extension is platform-specific. The iOS widget extension cannot be loaded as a macOS extension. So we add a new target `IoTPanelsMacWidgetExtension` whose `Info.plist` declares `NSExtension.NSExtensionPointIdentifier = "com.apple.widgetkit-extension"` and whose deployment target is macOS.

The extension's Swift source is the **same files** as the iOS widget extension, added to the new target's "Compile Sources" by reference. Any platform-specific divergence in the widget UI uses `#if os(macOS)` inside those files.

**Why:** Cross-platform widget extension is the supported pattern. Forking the widget code would force two cache code paths and two timeline providers, which is exactly the source-of-truth fragmentation we're avoiding for the main app.

### D5: macOS entitlements

For Mac App Store distribution under sandboxing:
- `com.apple.security.app-sandbox = YES`
- `com.apple.security.network.client = YES` (outbound HTTP / TCP for InfluxDB / Prometheus / MQTT)
- `com.apple.security.files.user-selected.read-write = YES` (backup import / export via `.fileImporter` / `.fileExporter`)

Kept from iOS:
- `com.apple.developer.icloud-container-identifiers = [iCloud.de.rnd7.iotpanels]`
- `com.apple.developer.icloud-services = [CloudKit]`
- `com.apple.security.application-groups = [group.de.rnd7.iotpanels]`

We do NOT need:
- `com.apple.security.network.server` — the app does not listen on any port.
- Bluetooth, audio, location, etc. — none used.

The entitlements file may need to be split per platform (`IoTPanels.entitlements` for iOS, `IoTPanels-macOS.entitlements` for macOS) if Xcode doesn't handle the conditional keys cleanly. We defer that decision to the first build attempt.

### D6: CloudKit sync works the same way on Mac

`NSPersistentCloudKitContainer` with the existing `iCloud.de.rnd7.iotpanels` container is unchanged. The Mac build creates the same CloudKit records, syncs to the same private database, and reads the same imports as iOS. CloudKit container schemas are not platform-specific.

The iOS-only `BGTaskScheduler` activity for CloudKit export does not exist on macOS. Instead, the Mac app gets push-style remote change notifications while running, and exports happen synchronously while the app is active. For an app that's typically used while open at a desk, this is sufficient.

### D7: Settings scene is a Mac-only addition

Mac apps surface settings via the standard ⌘, menu item, which SwiftUI wires up through a `Settings` scene at the App level. We will use the existing `AboutView` content as the basis for the Settings scene, possibly extracting a small `MacSettingsView` if About contains things that don't belong (e.g. version info that should stay in About proper).

iOS keeps its existing About tab with no change.

### D8: Distribution

- Same App Store Connect record (Universal Purchase): bundle ID stays `de.rnd7.iotpanels`.
- New macOS provisioning profile and Mac App Store signing certificate added to the developer account.
- TestFlight available for both platforms from the same App Store Connect record.
- App Review will assess the Mac binary separately. Expect at least one round of Mac-specific notes (window minimum size, About menu wording, sandbox justifications).

## Risks / Trade-offs

- [Audit finds more iOS-only modifiers than expected] → Mitigation: each one is a localized `#if os(iOS)` branch. The list in D3 is the floor, not the ceiling. Budget for adding ~5 more during the first Mac build attempt.
- [`NavigationSplitView` doesn't sit naturally with the existing `NavigationStack`-based detail flow] → Mitigation: keep using `NavigationStack` inside each split-view detail pane. SwiftUI supports nesting cleanly.
- [Mac users expect drag-and-drop, multi-select, keyboard navigation] → v1 ships without these advanced affordances. Add post-launch based on feedback.
- [`Form` renders very differently on macOS] → Acceptable. The Form-based settings / edit views are functional on Mac even if they look different from iOS. Refine after first build.
- [Mac widget extension behaves differently in Notification Center] → Mitigation: small `#if os(macOS)` adjustments inside the widget Swift files only. Do not fork the extension.
- [App Review rejects on missing Mac affordances] → Iterate. Add a minimum window size, About menu, Settings menu before first submission.
- [Color choices that look fine on iOS look wrong on macOS] → Mitigation: use SwiftUI semantic colors (`.background`, `.secondary`, `.tint`) by default. Branch only for the panel-card background, where the iOS `secondarySystemGroupedBackground` is specific.

## Migration Plan

1. **Audit pass.** Grep the entire main-app source for iOS-only API usage (`fullScreenCover`, `refreshable`, `swipeActions`, `Color(uiColor:`, `UIColor`, `UIDevice`, `UIScreen`, `UIPasteboard`, `UIImage`, `import UIKit`). Produce a complete list before changing anything.
2. **Fix UIColor.** Replace `Model/ColorUtilities.swift`'s `UIColor(self)` with a SwiftUI-only path.
3. **Project configuration.** Edit `project.pbxproj`: enable `macosx` SDK, change `SDKROOT` to `auto`, update supported platforms and device families. Set the macOS deployment target (likely 14.0 to match iOS feature usage).
4. **Add macOS entitlements.** Either extend the existing entitlements file or split into per-platform files.
5. **Build for Mac the first time.** Triage compile errors. For each iOS-only modifier, add the `#if os(iOS)` branch from D3.
6. **Add `MacRootView`.** Build the `NavigationSplitView` chrome in a new file. Update `IoTPanelsApp.swift` to switch root views per platform.
7. **Add `Settings` scene.** Wire it to existing About content.
8. **Add macOS widget extension target.** Reuse the iOS widget Swift sources.
9. **Smoke-test on Mac.** Open dashboards, demo home, Node Exporter dashboard (best showcase), real data sources, iCloud sync to / from iPhone, backup import / export.
10. **Distribution.** Add Mac record in App Store Connect, generate provisioning, archive, TestFlight.

**Rollback:** Revert `project.pbxproj` (`SDKROOT` back to `iphoneos`, `SUPPORTED_PLATFORMS` back to iOS-only, remove macOS entitlements). All Swift source changes are additive (`#if os(macOS)` branches do nothing on iOS) so they can stay.

## Open Questions

- Is the Mac widget actually high-priority for v1? Mac users may not use Notification Center widgets the way iPhone users do home-screen widgets. Could ship the Mac app first without the widget extension and add it in a follow-up.
- Should the Mac sidebar group sections (e.g. "Library: Dashboards / Widgets / Data Sources" vs "Settings: About"), or stay flat? Flat is simpler; group if the user finds flat cluttered.
- Minimum macOS deployment target — 14.0 covers all the iOS-17-equivalent SwiftUI APIs we use. Confirm during first build.
- Does the user want a "What's New" sheet on first Mac launch? Optional polish.
