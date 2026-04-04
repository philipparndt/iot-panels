## 1. Unit Formatter

- [x] 1.1 Create `Model/UnitFormatter.swift` with a static `format(value:unit:)` method that returns `(value: String, unit: String)` — define unit family lookup table with scale factors for bytes (1024-based), bytes/s, bits/s, watts, watt-hours, volts, amps, time, and frequency
- [x] 1.2 Implement the scaling logic: look up the base unit in the family table, convert to the base of that family, pick the best display scale where the resulting value is ≥ 1, format with smart decimal places (≥100 → 0dp, ≥10 → 1dp, <10 → 2dp)
- [x] 1.3 Handle compound rate units (e.g., "B/s") by splitting on "/" and scaling only the prefix part
- [x] 1.4 Pass through unknown units unchanged with the existing rounding logic

## 2. Integration

- [x] 2.1 Update `PanelCardView.swift` to use `UnitFormatter.format(value:unit:)` in place of `formatValue()` + manual unitSuffix for all display styles (singleValue, gauge, circularGauge, text, chart tooltips, calendar heatmap)
- [x] 2.2 Update `SingleValueWidget.swift` to use `UnitFormatter.format(value:unit:)`
- [x] 2.3 Update `IoTPanelsWatchWidget.swift` to use `UnitFormatter.format(value:unit:)`

## 3. Project & Build

- [x] 3.1 Add `UnitFormatter.swift` to Xcode project (all targets: main app, widget extension, watch widget extension)
- [x] 3.2 Build and verify no compiler errors

## 4. Testing

- [x] 4.1 Add unit tests for `UnitFormatter` — bytes scaling (B→KB→MB→GB→TB), watts scaling, time scaling, unknown units, empty units, rate units (B/s), smart decimal places
