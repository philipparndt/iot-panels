## 1. Core Data Model Changes

- [x] 1.1 Add `timeRange`, `aggregateWindow`, `aggregateFunction`, `comparisonOffset` optional String attributes to `WidgetDesignItem` entity
- [x] 1.2 Add wrapper properties on `WidgetDesignItem` extension: `effectiveTimeRange`, `effectiveAggregateWindow`, `effectiveAggregateFunction`, `wrappedComparisonOffset`, `needsBandAggregates`
- [x] 1.3 Add query builder methods on `WidgetDesignItem`: `buildQuery(for:)` and `buildComparisonQuery(for:)` that use item-level overrides (mirror DashboardPanel pattern)

## 2. Widget Item Configuration UI

- [x] 2.1 Expand display style picker in `WidgetItemConfigView` to show all `PanelDisplayStyle.allCases` with icons
- [x] 2.2 Add time range picker to `WidgetItemConfigView`
- [x] 2.3 Add aggregation window picker (filtered by time range) and function picker
- [x] 2.4 Add comparison offset picker (visible only for line-based display styles)
- [x] 2.5 Add heatmap color picker (visible for calendar heatmap styles)
- [x] 2.6 Add band opacity config (visible for band chart style)
- [x] 2.7 Save/restore original values on cancel (match EditPanelView pattern)

## 3. Widget Rendering

- [x] 3.1 Update `WidgetDesignPreviewView` to pass item's display style and styleConfig to `PanelRenderer` for all chart types (not just chart/singleValue/gauge)
- [x] 3.2 Handle band chart queries in widget preview — use `buildBandQuery` when `needsBandAggregates` is true
- [x] 3.3 Handle comparison data fetching and series building in widget preview
- [ ] 3.4 Verify compact rendering works for all new chart types at each widget size (2×2, 4×2, 4×4)

## 4. Widget Timeline Provider

- [x] 4.1 Update `SingleValueWidget` timeline provider to use per-item query overrides via `buildQuery(for:item:)`
- [x] 4.2 Add comparison data fetching in timeline provider when comparison offset is set
- [x] 4.3 Pass comparison data through to widget rendering

## 5. Translations

- [x] 5.1 Add translations for any new UI strings across all 8 supported languages

## 6. Testing

- [ ] 6.1 Verify all chart types render correctly in widget preview
- [ ] 6.2 Verify per-item time range and aggregation overrides produce correct queries
- [ ] 6.3 Verify comparison overlay renders in widgets
- [ ] 6.4 Verify cancel in widget item config restores original values
- [ ] 6.5 Verify lightweight Core Data migration works (no data loss on upgrade)
