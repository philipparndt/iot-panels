## Context

IoT Panels visualizes time-series data from InfluxDB, Prometheus, and MQTT. All current chart types operate on numeric data via `ChartDataPoint(time: Date, value: Double, field: String)`. Discrete state data (e.g., "on"/"off", "home"/"away", HVAC modes) has no visualization path — values that aren't parseable as numbers are discarded in the query pipeline.

State timeline charts are a standard visualization in monitoring tools (Grafana's "State timeline" panel, Home Assistant's history graphs). They show colored horizontal bars representing state durations over a time axis.

## Goals / Non-Goals

**Goals:**
- Render state timeline charts that show discrete states as colored horizontal bars over time
- Support string-valued data points in the data model without breaking existing numeric pipelines
- Allow users to configure state-to-color mappings
- Provide sensible automatic color assignment when no mapping is configured
- Work in both dashboard panels and iOS home screen widgets

**Non-Goals:**
- State change notifications or alerting
- Editing/controlling states (write-back to data sources)
- Multi-row state timeline in a single panel (each panel shows one entity; use multiple panels for multiple entities)
- Animated transitions between states

## Decisions

### 1. Extend ChartDataPoint with optional string state

**Decision:** Add an optional `state: String?` field to `ChartDataPoint` rather than creating a separate data model.

**Rationale:** `ChartDataPoint` is used throughout the rendering and caching pipeline (`PanelRenderer`, `ChartSeries`, `WidgetDataLoader`, widget timeline entries). A parallel model would require duplicating all of these paths. An optional field keeps the existing numeric pipeline untouched (`state` is nil for numeric data) while enabling state data to flow through the same infrastructure.

```swift
struct ChartDataPoint: Codable {
    let time: Date
    let value: Double
    let field: String
    let state: String?  // nil for numeric data, populated for state timelines
}
```

For state data, `value` can be set to 0 (or a hash of the state string for sorting purposes). The `state` field carries the display string.

**Alternatives considered:**
- Separate `StateDataPoint` struct: cleaner type safety but doubles the rendering pipeline complexity
- Enum with associated values: Swift Charts and Codable make this awkward

### 2. State-to-color mapping via StateColorMap in StyleConfig

**Decision:** Add a `stateColors: [StateColorEntry]?` array to `StyleConfig`, where each entry maps a state string to a hex color.

```swift
struct StateColorEntry: Codable, Equatable {
    var state: String
    var colorHex: String
}
```

**Rationale:** This follows the existing pattern of `ThresholdRule` in `StyleConfig`. Users can assign specific colors to specific states. When no mapping exists, fall back to automatic color assignment from a predefined palette.

**Automatic color palette:** Use a set of 8-10 distinguishable colors, assigned in order of first appearance. Common binary states ("on"/"off", "open"/"closed", "home"/"away") get semantic defaults (green/red, green/red, green/gray).

### 3. Rendering with SwiftUI rectangles, not Swift Charts

**Decision:** Render state timeline using raw SwiftUI (`GeometryReader`, `HStack`/`ZStack` with colored `RoundedRectangle`) rather than Swift Charts marks.

**Rationale:** Swift Charts doesn't have a native "state timeline" mark type. Approximating it with `BarMark` or `RectangleMark` requires fighting the framework (discrete X axis, stacking behavior, gaps). The calendar heatmap already uses custom SwiftUI drawing successfully — this follows that pattern. A time axis at the bottom can be drawn with simple `Text` labels positioned proportionally.

**Layout:**
```
┌──────────────────────────────────────────┐
│ ███ open ██████████ closed ████ open ███ │  ← colored rects
│ 06:00    09:00    12:00    15:00   18:00 │  ← time axis
└──────────────────────────────────────────┘
```

- Each state segment is a `RoundedRectangle` with width proportional to duration
- State label text is shown inside the segment if it fits, hidden if too narrow
- Time axis shows 3-5 evenly spaced labels

### 4. Query pipeline passthrough for string values

**Decision:** Modify `ChartDataParser` to detect non-numeric values and populate the `state` field instead of discarding them. The detection is simple: if a value string cannot be parsed as `Double`, treat it as a state string.

**Rationale:** This is the minimal change to enable state data flow. Data sources already return string values in `QueryResult.Row.values` — we just need to stop discarding them at the parsing stage.

## Risks / Trade-offs

- **[Widget size constraints]** → State timeline in small widgets may be unreadable. Mitigation: show only the current state label (like single value) when the widget is too narrow for a timeline. Use a minimum segment width threshold.
- **[High cardinality states]** → An entity with many unique states exhausts the color palette. Mitigation: cycle colors after the palette is exhausted; show a "N states" summary if there are more than 10 unique states.
- **[Cache compatibility]** → Adding `state` field to `ChartDataPoint` changes the Codable schema. Mitigation: `state` is optional with a default of nil, so existing cached JSON decodes without issues.
- **[Performance with many segments]** → Long time ranges with frequent state changes could create hundreds of rectangles. Mitigation: merge very short segments (< 2px wide) into the neighboring segment for rendering purposes.
