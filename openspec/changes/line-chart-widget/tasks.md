## 1. Model & Data Layer

- [x] 1.1 Add `bandChart` case to `PanelDisplayStyle` enum with display name "Band", icon, and include in `CaseIterable`
- [x] 1.2 Add `bandOpacity` (Double?) and `bandColor` (String?) properties to `StyleConfig`
- [x] 1.3 Add `comparisonOffset` (String?) attribute to `DashboardPanel` in CoreData model and `Dashboard+Wrapped.swift`
- [x] 1.4 Add comparison-related `TimeRange` helpers or a `ComparisonOffset` enum for the available offsets (none, 24h, 7d, 14d, 30d, 90d, 365d)

## 2. Query Layer — Multi-Aggregate

- [x] 2.1 Extend `SavedQuery.buildFluxQuery()` to accept an optional array of aggregate functions and generate a union query returning `<field>_min`, `<field>_max`, `<field>_mean` series
- [x] 2.2 Add a method to `SavedQuery` or `DashboardPanel` that determines if multi-aggregate is needed (i.e., display style is `bandChart`) and returns the appropriate function list
- [x] 2.3 Extend MQTT local aggregation to compute min/max/mean from cached data points grouped by aggregate window

## 3. Query Layer — Historical Comparison

- [x] 3.1 Add a method to build a time-shifted query given the current time range and a comparison offset (for InfluxDB: shift the `range()` start/stop back by offset)
- [x] 3.2 Add time-shift post-processing to align comparison results with the primary period's x-axis (shift timestamps forward by offset duration)
- [x] 3.3 Handle MQTT comparison: pull historical data from cache if available, skip if insufficient

## 4. Band Chart Rendering

- [x] 4.1 Add band chart rendering branch in `PanelRenderer` using `AreaMark(x:yStart:yEnd:)` for min/max band and `LineMark(x:y:)` for mean line
- [x] 4.2 Apply `bandOpacity` and `bandColor` from `StyleConfig` to the area fill
- [x] 4.3 Handle multi-series band charts (multiple fields each with their own min/max/mean band)
- [x] 4.4 Add selection tooltip support for band chart showing min, mean, max values at selected time

## 5. Historical Comparison Rendering

- [x] 5.1 In `PanelCardView`, fetch comparison data when `comparisonOffset` is set and pass as additional series to `PanelRenderer`
- [x] 5.2 Render comparison series with 0.3 opacity and dashed stroke style for line marks
- [x] 5.3 Render comparison band (if band chart + comparison) with further reduced opacity
- [x] 5.4 Add legend entry for comparison period (e.g., "Previous 7d") with dashed visual indicator

## 6. Panel Editor UI

- [x] 6.1 Add `bandChart` to the display style picker in `AddPanelView` and panel configuration views
- [x] 6.2 Add "Compare with" picker in panel config, visible only for line-based styles (line, line+points, band chart)
- [x] 6.3 Add band chart style options (opacity slider, color picker) in `StyleConfig` editor section
- [x] 6.4 Auto-select minimum aggregate window when user picks `bandChart` and current window is "None (raw)"

## 7. Demo & Testing

- [x] 7.1 Add band chart demo panel to `DemoSetup.swift` with sample min/max/mean data
- [x] 7.2 Add comparison demo panel showing current vs. previous period
- [x] 7.3 Verify band chart renders correctly on watchOS (compact mode)
- [x] 7.4 Verify backward compatibility — existing panels unchanged after CoreData migration
