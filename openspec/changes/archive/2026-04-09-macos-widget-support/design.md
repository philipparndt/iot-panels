## Context

The iOS/iPadOS builds of IoT Panels include a WidgetKit extension (`IoTPanelsWidgetExtension`) that offers multiple widget families (panel grids, single-value, countdown, transparent countdown). When the project added a native macOS target, the widget source files were wrapped in `#if !os(macOS)` and the extension was removed from the macOS build path (`SUPPORTED_PLATFORMS` set to iPhone-only, embed step gated with `platformFilter = ios`). This was done to unblock the Mac App Store submission after hitting:
- **ITMS-90296** — widget extension missing `com.apple.security.app-sandbox`.
- **ITMS-90896** — widget extension missing `__swift5_entry` (because the entire source was excluded on macOS, so the compiled `.appex` had no `@main`).

macOS has fully supported WidgetKit since macOS 11 (with expanded support in 14+), including `AppIntentConfiguration`, `systemSmall/Medium/Large` families, and Control Center widgets on 15+. The shared widget code is SwiftUI-based and almost platform-agnostic; the only iOS-only touch point identified so far is `Color(uiColor: .systemBackground)` in `IoTPanelsWidget.swift`.

Stakeholders:
- macOS users who want desktop/Notification Center widgets with parity to iOS.
- App Store submission pipeline — must keep passing validation.

## Goals / Non-Goals

**Goals:**
- Ship the existing widget families (`IoTPanelsWidget`, `SingleValueWidget`, `CountdownValueWidget`, `CountdownTransparentWidget`) on macOS with the same visual output and configuration flow as iOS.
- Pass Mac App Store validation (no ITMS-90296 / ITMS-90896 regressions).
- Keep iOS/iPadOS widget behavior unchanged.
- Share a single widget codebase across iOS and macOS — no parallel target.

**Non-Goals:**
- New widget designs or families exclusive to macOS.
- Lock Screen / StandBy / Home Screen accessory widget families (iOS-specific).
- Desktop-specific behaviors like hover interactions or window-resize adaptations beyond what WidgetKit already provides.
- Supporting macOS versions below the existing widget extension deployment target.

## Decisions

### Decision: Single shared widget extension, not a separate macOS target
**Choice:** Re-enable `macosx` in the existing `IoTPanelsWidgetExtension` target's `SUPPORTED_PLATFORMS`.

**Rationale:** The widget code is pure SwiftUI and the few platform-specific call sites can be handled with `#if os(macOS)` in-line. Creating a second extension target would duplicate build settings, entitlements, provisioning, bundle ID management, and code — for no user-visible benefit. WidgetKit itself already abstracts placement differences between iOS and macOS.

**Alternatives considered:**
- *Separate `IoTPanelsWidgetMac` target:* clean separation but doubles maintenance. Rejected.
- *Catalyst-based widget:* not supported by WidgetKit.

### Decision: Replace `UIColor.systemBackground` with a SwiftUI-native adaptive color
**Choice:** Use `Color(.windowBackgroundColor)` on macOS and keep `Color(uiColor: .systemBackground)` on iOS behind `#if`, or (preferred) switch both platforms to the SwiftUI semantic `Color(.systemBackground)` / `Color.primary.opacity(...)` style via `ShapeStyle.background` where possible.

**Rationale:** `Color(uiColor:)` is unavailable in AppKit. The "adaptive background" use case just wants the system's default container background, which `containerBackground(.background, for: .widget)` already provides when no explicit color is set. We can short-circuit the adaptive branch to rely on WidgetKit's default container background, removing the only UIKit dependency.

**Alternatives considered:**
- *`#if os(macOS)` with `Color(nsColor: .windowBackgroundColor)`:* works but clutters code. Acceptable fallback if `.background` style is not visually equivalent.

### Decision: Add `com.apple.security.app-sandbox = true` to widget entitlements
**Choice:** Update `IoTPanelsWidget.entitlements` to enable app-sandbox. Keep the same entitlements file shared across platforms; iOS ignores the key.

**Rationale:** Required by Mac App Store for all executables inside an app bundle. No behavioral impact on iOS. The app group entitlement already present is sufficient for Core Data / `WidgetDataLoader` sharing on both platforms.

### Decision: Keep the widget embed/dependency unconditional (remove `platformFilter = ios`)
**Choice:** Revert the `platformFilter = ios;` attributes added on the embed build file and target dependency. Re-add `macosx` to `SUPPORTED_PLATFORMS`.

**Rationale:** With a functioning macOS build, the extension must be embedded in `Contents/PlugIns/` of the macOS app for the widget to appear in the macOS widget gallery.

### Decision: macOS deployment target for the widget extension
**Choice:** Set the widget extension's `MACOSX_DEPLOYMENT_TARGET` to match the main macOS app target. If the main app is 14.0+, use 14.0; otherwise the minimum that supports the `AppIntentConfiguration` API used (`macOS 14.0`).

**Rationale:** `AppIntentConfiguration` and `WidgetConfigurationIntent` require macOS 14. Lower deployment targets would require a fallback to `IntentConfiguration`, which is not worth the complexity.

## Risks / Trade-offs

- **Risk:** Hidden iOS-only API usage in shared widget code (`PanelRenderer`, `WidgetDataLoader`, chart helpers) beyond the known `UIColor` call.
  **Mitigation:** Compile the widget target for macOS early in the task list and fix each error incrementally before touching the App Store flow.

- **Risk:** `AppIntents` entity queries touch Core Data via `PersistenceController.shared` on an extension process. CloudKit sync behavior on macOS widgets may differ from iOS (background refresh budgets are different).
  **Mitigation:** Keep the existing caching in `WidgetDataLoader`; do not introduce new sync assumptions in this change.

- **Risk:** Widget gallery preview on macOS requires a larger minimum deployment target; bumping it may exclude older macOS users.
  **Mitigation:** Align with main app's minimum macOS version; document the requirement in the release notes.

- **Risk:** Mac App Store may surface new validation warnings (e.g., hardened runtime requirements on the extension).
  **Mitigation:** Mirror the hardened runtime / sandbox settings already working for the main app target.

- **Trade-off:** Using `#if os(macOS)` branches in widget code reduces purity of the "single codebase" goal but avoids the complexity of a second target. Accepted as the pragmatic choice.

## Migration Plan

1. Enable macOS for the widget extension target and delete the `#if !os(macOS)` gates.
2. Iterate `xcodebuild -destination 'generic/platform=macOS'` until the extension compiles.
3. Add the sandbox entitlement.
4. Archive and run `xcodebuild -exportArchive` with an App Store export method locally to catch ITMS validation locally before submitting.
5. Upload a new build (bumped build number) and confirm no ITMS errors.

**Rollback:** If Apple rejects or the extension crashes in production on macOS, revert the `.pbxproj` change to re-apply `platformFilter = ios` and the narrowed `SUPPORTED_PLATFORMS`. The widget source is safe to leave unguarded because the target will simply not build on macOS.

## Open Questions

- What is the current minimum `MACOSX_DEPLOYMENT_TARGET` of the main `IoTPanels` app target? The widget must match or exceed it.
- Does the widget's `AppIntents` timeline provider behave correctly when the main app has never been launched on macOS (Core Data store bootstrapping inside an extension)?
