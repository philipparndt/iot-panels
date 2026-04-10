## 1. Model

- [x] 1.1 Add `showTrendLine: Bool?`, `trendMin: Double?`, `trendMax: Double?` fields to `StyleConfig`
- [x] 1.2 Add `supportsTrendLine` computed property on `PanelDisplayStyle` returning true for `.singleValue` and `.circularGauge`

## 2. Background Sparkline View

- [x] 2.1 Create `BackgroundSparklineView` in `Views/Dashboard/` that takes data points, min/max range, accent color, and renders a filled area path with low opacity
- [x] 2.2 Support circular clipping mode for use inside circular gauge

## 3. Panel Integration

- [x] 3.1 Wrap `singleValueBody` content in a `ZStack` with `BackgroundSparklineView` as background when `showTrendLine` is true
- [x] 3.2 Wrap `circularGaugeBody` ring in a `ZStack` with `BackgroundSparklineView` (circle-clipped) as background when `showTrendLine` is true
- [x] 3.3 Implement auto range logic: use `trendMin`/`trendMax` if set, default to 0–100 for `%` unit, otherwise derive from data

## 4. Configuration UI

- [x] 4.1 Add "Trend Line" config section in `DashboardView` panel editor (toggle + conditional min/max fields) gated by `supportsTrendLine`
- [x] 4.2 Add "Trend Line" config section in `WidgetItemConfigView` gated by `supportsTrendLine`

## 5. Verify

- [x] 5.1 Build and verify no compiler errors across all targets
