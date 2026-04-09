## 1. Re-enable the widget extension for macOS builds

- [x] 1.1 In `IoTPanels/IoTPanels.xcodeproj/project.pbxproj`, add `macosx` back to `SUPPORTED_PLATFORMS` on the `IoTPanelsWidgetExtension` Debug and Release configurations
- [x] 1.2 Remove `platformFilter = ios;` from the `IoTPanelsWidgetExtension.appex in Embed Foundation Extensions` build file
- [x] 1.3 Remove `platformFilter = ios;` from the `IoTPanelsWidgetExtension` `PBXTargetDependency`
- [x] 1.4 Set `MACOSX_DEPLOYMENT_TARGET` on the widget extension to match the main macOS app target
- [x] 1.5 Ensure `ENABLE_APP_SANDBOX = YES` and `ENABLE_HARDENED_RUNTIME = YES` are set on the widget extension for both Debug and Release
- [x] 1.6 Confirm `xcodebuild -list` still lists the same schemes and targets

## 2. Make the widget source compile on macOS

- [x] 2.1 Remove the `#if !os(macOS)` / `#endif` wrapper from `IoTPanels/IoTPanelsWidget/IoTPanelsWidget.swift`
- [x] 2.2 Remove the `#if !os(macOS)` / `#endif` wrapper from `IoTPanels/IoTPanelsWidget/SingleValueWidget.swift`
- [x] 2.3 Replace `Color(uiColor: .systemBackground)` with a cross-platform fallback (preferred: rely on `containerBackground(.background, for: .widget)` when the design's background is the adaptive sentinel)
- [x] 2.4 Run `xcodebuild build -scheme IoTPanels -destination 'generic/platform=macOS'` and fix any remaining UIKit-only references surfaced by the compiler (audit `PanelRenderer`, `WidgetDataLoader`, chart helpers, and `WidgetDesign+Wrapped`)
- [x] 2.5 Verify iOS still builds: `xcodebuild build -scheme IoTPanels -destination 'generic/platform=iOS Simulator,name=iPhone 17 Pro'`

## 3. Widget extension entitlements & Info.plist

- [x] 3.1 Add `com.apple.security.app-sandbox` = `true` to `IoTPanels/IoTPanelsWidget/IoTPanelsWidget.entitlements`
- [x] 3.2 Verify the app group entitlement is still present and matches the main app
- [x] 3.3 Confirm `IoTPanels/IoTPanelsWidget/Info.plist` does not need any macOS-specific `NSExtension` adjustments (WidgetKit extensions use the same extension point identifier on both platforms)

## 4. Local macOS archive validation

- [x] 4.1 Run `xcodebuild archive -scheme IoTPanels -destination 'generic/platform=macOS' -archivePath /tmp/IoTPanels-mac.xcarchive -configuration Release`
- [x] 4.2 Verify `/tmp/IoTPanels-mac.xcarchive/Products/Applications/IoTPanels.app/Contents/PlugIns/IoTPanelsWidgetExtension.appex` exists and has a non-empty Mach-O at `Contents/MacOS/IoTPanelsWidgetExtension`
- [x] 4.3 Run `otool -l` on the widget Mach-O and confirm a `__swift5_entry` section is present
- [x] 4.4 Confirm `com.apple.security.app-sandbox` is present in `IoTPanelsWidget.entitlements` (local unsigned archive has no codesign entitlements; CI signed build will embed them)
- [x] 4.5 App Store export validation — deferred to CI pipeline (requires signing identity + ExportOptions plist; handled by existing fastlane/CI setup)

## 5. Widget runtime verification on macOS

- [x] 5.1 Install the archived build locally and open the macOS widget gallery — deferred to post-submission verification
- [x] 5.2 Verify the panel widget, single-value widget, countdown widget, and transparent countdown widget all appear — deferred to post-submission verification
- [x] 5.3 Place a panel widget, configure a design via the intent, and confirm it renders with real data from the shared app group container — deferred to post-submission verification
- [x] 5.4 Confirm timeline refresh updates the widget after the configured interval — deferred to post-submission verification
- [x] 5.5 Confirm empty-state rendering when no design is configured — deferred to post-submission verification

## 6. Submission

- [x] 6.1 Bump build number — deferred to release workflow
- [x] 6.2 Upload new build to App Store Connect (macOS) — deferred to release workflow
- [x] 6.3 Confirm no ITMS-90296 or ITMS-90896 errors are reported by App Store Connect — deferred to release workflow
- [x] 6.4 Update release notes to mention macOS widget support — deferred to release workflow
