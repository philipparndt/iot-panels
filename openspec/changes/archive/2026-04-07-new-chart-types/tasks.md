## 1. Enum & Model Setup

- [x] 1.1 Add `sparkline`, `stackedBar`, `stackedArea`, `statusIndicator`, `table` cases to `PanelDisplayStyle` with displayName, icon, and isLineBased values
- [x] 1.2 Update `category` computed property (if chart-type-picker-sections is implemented) to assign new types to appropriate categories

## 2. Sparkline

- [x] 2.1 Add sparkline rendering path in `PanelRenderer` — reuse line chart logic with axes, grid, and legend hidden, show last-value label at trailing edge
- [x] 2.2 Add sparkline demo data to `DemoService`

## 3. Stacked Charts

- [x] 3.1 Add stacked bar rendering path in `PanelRenderer` using Swift Charts `BarMark` with `.position(stacking: .standard)` for multi-series data
- [x] 3.2 Add stacked area rendering path in `PanelRenderer` using Swift Charts `AreaMark` with stacking for multi-series data
- [x] 3.3 Add single-series fallback — render as regular bar/area when only one series is present
- [x] 3.4 Add stacked chart demo data to `DemoService` with multiple series

## 4. Status Indicator

- [x] 4.1 Add status indicator rendering in `PanelRenderer` — colored `Circle` with current value and label, color from `StyleConfig.thresholds`
- [x] 4.2 Add compact layout variant for iOS widgets (inline circle + value)
- [x] 4.3 Add status indicator demo data to `DemoService`

## 5. Table

- [x] 5.1 Add table rendering in `PanelRenderer` — SwiftUI `Grid` or `LazyVGrid` with Time, Field, Value/State columns
- [x] 5.2 Add scrolling support within panel bounds for long result sets
- [x] 5.3 Add compact widget variant showing only the most recent 2-3 rows
- [x] 5.4 Add table demo data to `DemoService`

## 6. Picker Integration

- [x] 6.1 Add all new display styles to the picker in `AddPanelView.swift`
- [x] 6.2 Add all new display styles to the picker in `WidgetItemConfigView.swift`
