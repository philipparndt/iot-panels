## 1. Category Model

- [x] 1.1 Add `ChartCategory` enum with cases `timeSeries`, `values`, `grid`, `other` — each with `displayName` and `sortOrder`
- [x] 1.2 Add `category: ChartCategory` computed property to `PanelDisplayStyle` with exhaustive switch mapping each style to its category

## 2. Dashboard Panel Picker

- [x] 2.1 Refactor `AddPanelView` display style picker from flat `ForEach` to grouped sections using `ChartCategory` with section headers
- [x] 2.2 Verify section order matches spec: Time Series, Values, Grid, Other

## 3. Widget Item Picker

- [x] 3.1 Refactor `WidgetItemConfigView` display style picker from flat list to grouped sections matching the dashboard panel picker layout
