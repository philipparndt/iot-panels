## Context

Dashboard panels currently render charts with persisted settings (time range, aggregation, comparison offset) stored in Core Data via `DashboardPanel`. Any change a user makes to explore data is permanent. The app uses SwiftUI with `PanelCardView` as the main chart component, which delegates rendering to `PanelRenderer` and data fetching to `DataSourceServiceProtocol` implementations.

The existing infrastructure already supports:
- Multiple time ranges and aggregate windows (`TimeRange`, `AggregateWindow` enums)
- Comparison overlays via `comparisonOffset` on `DashboardPanel`
- All chart display styles through `PanelRenderer`
- Query building for all backends (`buildQuery(for:)` on `SavedQuery`)

## Goals / Non-Goals

**Goals:**
- Allow users to open any dashboard panel in a fullscreen explorer overlay
- Provide transient controls for time range, aggregation, comparison, and scrolling
- Reuse existing chart rendering and query infrastructure — no duplication
- All explorer state is ephemeral; closing discards changes
- Support panning/scrolling through data by shifting the time window

**Non-Goals:**
- Persisting explorer state or "save as new panel" functionality (future enhancement)
- Adding new chart types or display styles
- Modifying the query builder or data source configuration
- Export/sharing of explored data
- watchOS support (iOS only for now)

## Decisions

### 1. Fullscreen overlay via `.fullScreenCover`

Use SwiftUI's `.fullScreenCover` modifier on `PanelCardView` to present the explorer. This provides a native fullscreen experience with standard dismiss gestures.

**Alternative considered**: Navigation push — rejected because the explorer is a transient inspection tool, not a navigation destination. A modal overlay better communicates its ephemeral nature.

### 2. In-memory state model with `@Observable`

Create a `ChartExplorerState` class (using `@Observable` macro) that holds all transient settings: time range, aggregate window, aggregate function, comparison offset, and the current time window position for scrolling. Initialize it from the panel's persisted values.

**Alternative considered**: `@State` properties directly in the view — rejected because the state is complex enough to warrant a dedicated model, and it needs to be shared between the main chart and the control toolbar.

### 3. Time scrolling via window offset

Implement scrolling by maintaining a `windowOffset: TimeInterval` on the explorer state. The query's time range is shifted by this offset. "Step" buttons move the offset by the width of the current time range (e.g., if viewing 24h, step moves ±24h). A "Reset" button returns to offset 0 (current time).

**Alternative considered**: Drag gesture on the chart — rejected for v1 due to complexity of integrating with Swift Charts' built-in gestures. Step buttons are simpler and more predictable. Chart drag could be added later.

### 4. Reuse query building with parameter overrides

Rather than duplicating query logic, pass the explorer's transient settings to the existing `SavedQuery` query builder methods. Create a lightweight `QueryOverrides` struct that the explorer injects. The query builder checks for overrides before falling back to the persisted panel values.

**Alternative considered**: Cloning the `SavedQuery` in memory — rejected because Core Data managed objects are awkward to clone without inserting into the context, and we explicitly want to avoid any persistence side effects.

### 5. Toolbar layout for controls

Place exploration controls in a bottom toolbar with segmented/compact controls:
- Time range picker (horizontal scroll of presets)
- Aggregate window + function pickers (menus)
- Comparison offset toggle (menu)
- Step backward / reset / step forward buttons for scrolling

**Alternative considered**: Side panel — rejected because iOS screen width is limited and charts benefit from full width.

## Risks / Trade-offs

- **[Performance]** Changing settings triggers a new network query each time → Mitigated by debouncing rapid changes (300ms) and showing the previous data until the new result arrives.
- **[Complexity of QueryOverrides]** Injecting overrides into existing query builders adds a parameter to existing methods → Mitigated by making it an optional parameter with a default of `nil`, keeping the existing call sites unchanged.
- **[MQTT panels]** MQTT data sources stream real-time data and don't support arbitrary time ranges → Mitigated by disabling time range / scrolling controls for MQTT panels and only allowing aggregation changes on cached data.
- **[Chart readability]** Switching between very different aggregate windows can make data look radically different → Mitigated by showing the current effective settings clearly in the toolbar so users always know what they're viewing.
