## Why

IoT Panels currently supports only numeric time-series visualizations. Discrete state data — door open/closed, HVAC modes, presence — cannot be meaningfully displayed. A state timeline chart fills this gap and is essential for future Home Assistant integration, where most entities are state-based rather than numeric.

## What Changes

- Add a new `stateTimeline` display style to `PanelDisplayStyle` that renders discrete states as colored horizontal bars over time
- Extend the data model to support string-valued data points alongside the existing numeric `ChartDataPoint`
- Add state-to-color mapping configuration so users can assign colors to specific state values (e.g., "open" = green, "closed" = red)
- Add automatic state detection in the query pipeline to identify when data contains discrete states vs. numeric values
- Render state timeline using SwiftUI with colored rectangles, state labels, and a time axis

## Capabilities

### New Capabilities
- `state-timeline`: State timeline chart type that visualizes discrete string states as colored horizontal bars over time, including data model extensions, rendering, and configuration

### Modified Capabilities
- `widget-chart-types`: Add stateTimeline to the set of available chart types

## Impact

- `PanelDisplayStyle` enum gains a new case
- `ChartDataPoint` or a parallel model needs to support string values
- `PanelRenderer` needs a new rendering path for state timeline
- `StyleConfig` needs state-color mapping configuration
- `ServiceFactory` / query pipeline may need adaptation to pass through string values that are currently discarded
- Widget and dashboard panel views need to support the new type in their pickers
