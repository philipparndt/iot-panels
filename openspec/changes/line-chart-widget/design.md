## Context

IoTPanels currently renders line charts using Swift Charts with a single aggregate function per query (mean, max, min, etc.). The `PanelRenderer` switches on `PanelDisplayStyle` to choose between line, bar, scatter, single value, gauge, and heatmap views. Data flows through `SavedQuery` → `ChartDataPoint` → `ChartSeries` → `PanelRenderer`.

The app already supports multi-series charts (multiple fields per query), but each series uses the same aggregate function. There is no mechanism to fetch multiple aggregates (min + max + mean) for the same field, nor to overlay data from a previous time period.

## Goals / Non-Goals

**Goals:**
- Add a band chart display style showing min/max range as a filled area with mean line
- Support multi-aggregate queries (min, max, mean in one request) for InfluxDB and MQTT backends
- Add historical comparison overlay on line-based charts with configurable period offset
- Keep changes backward-compatible — existing panels and queries continue to work unchanged
- Support both InfluxDB and MQTT data sources

**Non-Goals:**
- Custom aggregate function combinations beyond min/max/mean for band charts
- Comparison across different measurements or fields (only same-field time-shifted)
- Pinch-to-zoom or interactive time range scrubbing (separate feature)
- Band chart for bar or scatter styles

## Decisions

### 1. Band chart as a new PanelDisplayStyle case

Add `.bandChart` to `PanelDisplayStyle`. This keeps the rendering pipeline consistent — `PanelRenderer` gains one new branch. The band chart always uses three aggregates (min, max, mean) regardless of the panel's `aggregateFunction` setting.

**Alternative considered**: Overloading the existing `.chart` style with a "show band" toggle in `StyleConfig`. Rejected because band charts have fundamentally different query requirements (three aggregates) and distinct visual rendering logic.

### 2. Multi-aggregate query via parallel Flux union

For InfluxDB, generate three separate `aggregateWindow` calls (one per function) and union them. Each result is tagged with its aggregate type in the `field` column (e.g., `temperature_mean`, `temperature_min`, `temperature_max`). This maps cleanly onto the existing `ChartSeries` model — three series per field.

For MQTT, aggregate locally from the cached raw data points, since MQTT data is already stored in memory.

**Alternative considered**: A single Flux query with `reduce()` computing all three. Rejected because `aggregateWindow` is more readable and InfluxDB optimizes it well.

### 3. Comparison period as a time offset on DashboardPanel

Add a `comparisonOffset` property to `DashboardPanel` (stored as a `TimeRange` raw value or `nil` for disabled). When set, the panel fires a second query shifted back by that offset and renders the result as a dimmed series behind the primary data.

The comparison series reuses the same `ChartSeries` model with a `.opacity(0.3)` modifier and dashed line style to visually distinguish it from the current data.

**Alternative considered**: Storing comparison config in `StyleConfig`. Rejected because comparison affects query behavior (what data to fetch), not just visual styling.

### 4. StyleConfig extensions for band chart

Add to `StyleConfig`:
- `bandOpacity: Double` (default 0.2) — fill opacity between min and max
- `bandColor: String?` (nil = use series color) — optional override

Keep it minimal. The mean line uses the series accent color; the band area uses the same color at reduced opacity.

### 5. Rendering with Swift Charts AreaMark + LineMark

The band chart renders using:
- `AreaMark(x: time, yStart: min, yEnd: max)` for the filled band
- `LineMark(x: time, y: mean)` for the center line

This is native Swift Charts API, no custom drawing needed. The comparison overlay uses the same marks with reduced opacity and a dashed `strokeStyle`.

## Risks / Trade-offs

- **Query performance**: Band chart queries 3x data (min+max+mean). → Mitigation: aggregation windows already reduce point counts; the union approach parallelizes well in InfluxDB.
- **Comparison doubles query load**: Each comparison-enabled panel fires two queries. → Mitigation: comparison is opt-in per panel; caching still applies.
- **MQTT aggregate accuracy**: Local aggregation from cached MQTT data may miss points if the cache window is shorter than the display range. → Mitigation: document that band/comparison features work best with InfluxDB; MQTT uses best-effort from available data.
- **CoreData migration**: Adding properties to `DashboardPanel` requires a lightweight migration. → Mitigation: new properties are optional with defaults, which CoreData handles automatically.
