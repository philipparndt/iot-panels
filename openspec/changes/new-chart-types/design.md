## Context

IoT Panels renders charts via `PanelRenderer`, which switches on `PanelDisplayStyle` and delegates to Swift Charts (`LineMark`, `BarMark`, `PointMark`, `AreaMark`) or custom SwiftUI views (gauges, heatmaps). The data model is `ChartSeries` containing `[ChartDataPoint]`. Multi-series support already exists. Adding new chart types means adding enum cases, rendering paths, and optional style configuration.

## Goals / Non-Goals

**Goals:**
- Add 5 new display styles: sparkline, stacked bar, stacked area, status indicator, table
- Each works in dashboard panels and iOS widgets
- Reuse existing data model and query pipeline — no new data structures needed
- Follow established patterns in `PanelRenderer` for consistency

**Non-Goals:**
- Interactive table sorting/filtering (read-only display only)
- Custom sparkline shapes (just a simple line)
- Stacked percentage mode (absolute values only for now)

## Decisions

### 1. Sparkline: strip axes from existing line chart

**Decision:** Sparkline reuses the existing `chartBody(chartType: .line)` logic but strips axes, grid, legends, and annotations. It shows only the line with optional last-value label.

**Rationale:** The line rendering is already solid. Sparkline is a presentation variation, not a fundamentally different chart. This avoids duplicating chart logic.

**Implementation:** Add a `isSparkline` flag check in `chartBody` that hides `chartXAxis`, `chartYAxis`, and `chartLegend` modifiers. Alternatively, create a thin wrapper that calls `Chart { LineMark(...) }` with minimal configuration.

### 2. Stacked charts: use Swift Charts stacking

**Decision:** Use Swift Charts' built-in `.stacking` modifier on `BarMark` and `AreaMark` for multi-series data.

**Rationale:** Swift Charts natively supports stacking — `BarMark` with `series` foreground style and `.position(stacking: .standard)`. This is the idiomatic approach and handles layout, legends, and tooltips automatically.

**Constraint:** Stacked charts only make sense with multi-series data. When a single series is provided, fall back to regular bar/area chart rendering.

### 3. Status indicator: custom SwiftUI, not a chart

**Decision:** Render status indicator with a colored `Circle` and `Text` label in a `VStack`/`HStack`. Color is determined by threshold rules from `StyleConfig.thresholds`.

**Rationale:** This is the simplest visualization — no axes, no time series, just "what's the current value and is it good?". The threshold system already maps value ranges to colors, so this reuses existing infrastructure.

**Layout options:**
- Dashboard panel: large centered circle + value + label
- Widget: compact circle + value inline

### 4. Table: SwiftUI Grid with query result columns

**Decision:** Render table using SwiftUI `Grid` (iOS 16+) or `LazyVGrid` showing the raw `ChartDataPoint` data as rows with time, value, and field columns.

**Rationale:** Users sometimes want to see exact numbers. A simple table of the same data that feeds charts is the most straightforward approach. No need for a separate query mechanism.

**Columns:** Time | Field | Value (for numeric) or State (for string states). Scrollable within the panel height.

### 5. StyleConfig additions

**Decision:** Minimal additions to `StyleConfig`:
- Status indicator reuses existing `thresholds` for color mapping — no new fields needed
- Table needs no style config initially

**Rationale:** Avoid adding configuration until users need it. Sparkline and stacked charts work with default styling. Status indicator piggybacks on thresholds.

## Risks / Trade-offs

- **[Stacked chart with wrong data]** → Users may select stacked chart with single-series data, getting a regular bar/area. Mitigation: show a hint or auto-fallback is fine — this matches current `.auto` behavior.
- **[Table in small widgets]** → Tables need space. Mitigation: in small widgets, show only the latest 2-3 rows or fall back to single value display.
- **[5 new types at once]** → Larger change surface. Mitigation: each type is independent — they can be implemented and tested individually. Tasks are structured per chart type.
