## 1. New Display Styles — Model

- [x] 1.1 Add `.circularGauge` and `.text` cases to `PanelDisplayStyle` enum in `Dashboard+Wrapped.swift` with display names "Circular Gauge" and "Text", appropriate SF Symbol icons, and `isLineBased` returning false for both

## 2. Circular Gauge Rendering

- [x] 2.1 Add `circularGaugeBody` rendering in `PanelCardView.swift` — use SwiftUI `Gauge` with circular style, display current value in center, color the ring using `GaugeColorScheme` interpolation, respect `StyleConfig` gaugeMin/gaugeMax
- [x] 2.2 Handle multi-series in circular gauge — show first series in ring, list all series values in a compact legend below
- [x] 2.3 Wire `.circularGauge` case in the main panel rendering switch in `PanelCardView.swift`

## 3. Text Panel Rendering

- [x] 3.1 Add `textBody` rendering in `PanelCardView.swift` — extract latest value from data, display as large centered text with optional unit, format numeric values (trim excessive decimals), pass through non-numeric strings
- [x] 3.2 Wire `.text` case in the main panel rendering switch in `PanelCardView.swift`

## 4. Display Style Exhaustiveness

- [x] 4.1 Add `.circularGauge` and `.text` cases to all switch statements on `PanelDisplayStyle` across the codebase (AddPanelView, WidgetDesignEditorView, PanelCardView style picker, etc.) — route circularGauge like gauge and text like singleValue where applicable

## 5. Dashboard Template Model

- [x] 5.1 Create `Services/DashboardTemplate.swift` with `DashboardTemplate`, `PanelTemplate`, and `QueryTemplate` structs — include id, name, description, icon, backendType, and panel list
- [x] 5.2 Add `DashboardTemplateRegistry` enum with a static method that returns all available templates, with filtering by `BackendType`
- [x] 5.3 Add a `func apply(to home: Home, dataSource: DataSource, context: NSManagedObjectContext)` method on `DashboardTemplate` that creates Dashboard, SavedQueries, and DashboardPanels

## 6. Node Exporter Lite Template

- [x] 6.1 Define the "Node Exporter Lite" template in `DashboardTemplateRegistry` with 8 panels: uptime (text), CPU/memory/disk gauges (circularGauge), CPU/memory over time (chart), network traffic (chart), disk I/O (chart) — all using raw PromQL queries
- [x] 6.2 Set appropriate StyleConfig on gauge panels (gaugeMin: 0, gaugeMax: 100, greenToRed scheme) and time ranges / aggregate windows on chart panels

## 7. Template Picker UI

- [x] 7.1 Create `Views/Dashboard/DashboardTemplatePickerView.swift` — sheet showing "Blank Dashboard" and list of available templates, each with icon, name, description, and panel count
- [x] 7.2 Add data source selection step when a template is chosen — show a picker of compatible data sources (filtered by template's backendType)
- [x] 7.3 Wire template picker into `DashboardListView` — show the picker when user taps "Add Dashboard", replacing or augmenting the current creation flow

## 8. Integration & Polish

- [x] 8.1 Add localized strings for template names, descriptions, new display style names, and UI labels in `Localizable.xcstrings`
- [x] 8.2 Add new files to Xcode project (all targets as appropriate)
- [x] 8.3 Build and verify no compiler errors

## 9. Testing

- [x] 9.1 Add unit tests for `DashboardTemplate.apply()` — verify correct entity creation counts and relationships
- [x] 9.2 Add unit tests for `DashboardTemplateRegistry` filtering by backend type
- [x] 9.3 Verify circular gauge and text panel render correctly in dashboards with demo or Prometheus data
