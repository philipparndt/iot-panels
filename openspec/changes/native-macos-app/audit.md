# iOS-only API audit for native macOS port

Produced as part of tasks 1.1–1.4 of `native-macos-app`. Every finding below will compile-fail or mis-behave against the macOS SDK and needs the listed replacement.

Scope: main app source tree (`IoTPanels/IoTPanels/`) and the iOS widget extension (`IoTPanels/IoTPanelsWidget/`). The watchOS targets and Info.plist are out of scope.

## 1.1 — Direct UIKit references

| File:line | Match | Replacement |
|---|---|---|
| `IoTPanels/Model/ColorUtilities.swift:32` | `let uiColor = UIColor(self)` | Use `Color.resolve(in:)` (iOS 17 / macOS 14) to extract RGB components without UIKit. See §2. |
| `IoTPanels/Views/AboutView.swift:147–176` | `BackupDocumentPicker: UIViewControllerRepresentable` wrapping `UIDocumentPickerViewController` | Replace the sheet-presented picker with SwiftUI's `.fileImporter`. Already used elsewhere (`MQTTFormView`, `DataSourceListView`). |
| `IoTPanels/Services/DataExporter.swift:6–14` | `DataShareSheetView: UIViewControllerRepresentable` wrapping `UIActivityViewController` | On macOS use `.fileExporter` (or a one-shot `NSSavePanel`) from the call sites. Wrap the struct in `#if os(iOS)` and branch the three call sites (`AboutView`, `ChartExplorerView`, `DashboardView`). |
| `IoTPanels/Views/DataSource/DataSourceListView.swift:213–220` | `ShareSheetView: UIViewControllerRepresentable` wrapping `UIActivityViewController` | Same strategy as `DataShareSheetView` — wrap in `#if os(iOS)` and branch the caller. |

No other `import UIKit`, `UIColor`, `UIScreen`, `UIDevice`, `UIPasteboard`, `UIImage`, or `UIApplication` references exist in the main app source.

## 1.2 — iOS-only SwiftUI modifiers

### `Color(uiColor: …)` / `Color(.system…)`

| File:line | Expression | Replacement |
|---|---|---|
| `Views/Dashboard/PanelCardView.swift:24` | `Color(uiColor: .secondarySystemGroupedBackground)` | `#if os(macOS) Color(NSColor.controlBackgroundColor) #else Color(uiColor: .secondarySystemGroupedBackground) #endif` (or extract a small cross-platform helper). |
| `Views/Dashboard/ChartExplorerView.swift:36` | `Color(uiColor: .systemGroupedBackground)` | `#if os(macOS) Color(NSColor.windowBackgroundColor) #else Color(uiColor: .systemGroupedBackground) #endif` |
| `Views/Dashboard/ChartExplorerView.swift:242, 264, 287` | `Color(uiColor: .tertiarySystemFill)` | `#if os(macOS) Color.secondary.opacity(0.12) #else Color(uiColor: .tertiarySystemFill) #endif` |
| `Views/Dashboard/DashboardView.swift:280` | `Color(.secondarySystemGroupedBackground)` | Same as PanelCardView. |
| `Views/WidgetDesigner/WidgetDesignEditorView.swift:283` | `Color(.secondarySystemGroupedBackground)` | Same. |
| `Views/WidgetDesigner/WidgetDesignEditorView.swift:373` | `Color(uiColor: .secondarySystemGroupedBackground)` | Same. |
| `Model/WidgetDesign+Wrapped.swift:177` | `Color(uiColor: .systemBackground)` | `#if os(macOS) Color(NSColor.windowBackgroundColor) #else Color(uiColor: .systemBackground) #endif` |
| `IoTPanelsWidget/IoTPanelsWidget.swift:238` | `Color(uiColor: .systemBackground)` | Same branch inside the shared widget file. |

Recommendation: introduce a single `Color.platformPanelBackground` / `Color.platformGroupedBackground` helper in an extension file so the `#if` lives in one place. The audit tasks permit either approach; a small helper is cleaner for 8 sites.

### `.fullScreenCover`

| File:line | Replacement |
|---|---|
| `Views/Dashboard/DashboardView.swift:93` | Branch: `#if os(macOS) .sheet(item: $exploringPanel) … #else .fullScreenCover(item: $exploringPanel) … #endif`. |

### `.refreshable`

| File:line | Replacement |
|---|---|
| `Views/Dashboard/DashboardView.swift:292` | Wrap with `#if os(iOS)`. Mac users refresh via the existing toolbar/menu refresh action. |

### `.swipeActions`

No matches found in the main app source. `.swipeActions` is not currently used — row deletion already goes through context menus.

### `.navigationBarTitleDisplayMode(.inline)`

21 call sites across `AboutView`, `DisplayStylePickerView`, `DashboardView`, `DashboardListView`, `ChartExplorerView`, `AddPanelView`, `QueryBuilderView`, `WidgetItemConfigView`, `ManualQueryEditorView`, `WidgetDesignListView`, `PrometheusQueryBuilderView`, `MQTTQueryBuilderView`, `PrometheusSetupView`, `DashboardTemplatePickerView` (2), `MQTTBrokerFormView`, `MQTTFormView` (2), `AddWidgetItemView`, `InfluxDB3SetupView`, `MQTTSetupView`, `InfluxDB2SetupView`, `InfluxDB1SetupView`, `MQTTTopicDiscoveryPage`.

Strategy: add a small view-extension helper that is a no-op on macOS:

```swift
extension View {
    @ViewBuilder func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
```

Then `replace_all` the 21 call sites to `.inlineNavigationTitle()`. Keeps the diff small and readable.

## 1.3 — File pickers / UTType

- `.fileImporter` is used in `MQTTFormView.swift:638` and `DataSourceListView.swift:105` — cross-platform, no changes needed.
- `UTType` is imported via `UniformTypeIdentifiers` in `Model/BrokerFileType.swift` and `MQTTFormView.swift` — cross-platform, no changes.
- `.fileExporter` is NOT currently used anywhere. The two share/export flows (`DataShareSheetView`, `ShareSheetView`) rely on iOS `UIActivityViewController`. Both must be branched to `.fileExporter` on macOS (see §1.1).
- Info.plist `UTTypeIdentifier` entries — kept, no platform impact.

## 1.4 — Summary of replacement strategies

- **Cross-platform helper (preferred):** introduce `Color.platformGroupedBackground`, `Color.platformSecondaryGroupedBackground`, `Color.platformTertiaryFill`, and `View.inlineNavigationTitle()`. 8 color sites + 21 navigation sites collapse to one `#if` each.
- **Per-call `#if`:** the two remaining iOS-only modifier sites in `DashboardView` (`fullScreenCover` and `refreshable`) are branched directly.
- **`#if os(iOS)` wrappers:** `DataShareSheetView`, `ShareSheetView`, `BackupDocumentPicker`, and their call sites. macOS gets a `.fileExporter` / `.fileImporter` branch instead.
- **`ColorUtilities.complementary()`:** rewritten to use `Color.resolve(in:)` with no UIKit.

Expected number of `#if` blocks after the refactor: ~6 call sites + 1 helper file. Well within the "budget for ~5 more" headroom in `design.md`.

No iOS-private APIs or `UIHostingController` / `keyWindow` references were found.
