## 1. Data Model

- [x] 1.1 Add optional `state: String?` field to `ChartDataPoint` in `PanelCardView.swift` with default nil value
- [x] 1.2 Add `StateColorEntry` struct (state: String, colorHex: String) to `StyleConfig.swift`
- [x] 1.3 Add `stateColors: [StateColorEntry]?` field to `StyleConfig`
- [x] 1.4 Add `stateTimeline` case to `PanelDisplayStyle` enum with displayName "State Timeline" and appropriate SF Symbol icon

## 2. Query Pipeline

- [x] 2.1 Update `ChartDataParser` to detect non-numeric values and populate `ChartDataPoint.state` instead of discarding them, setting `value` to 0
- [x] 2.2 Verify cached data backward compatibility — existing cached JSON with no `state` field decodes correctly

## 3. State Color Logic

- [x] 3.1 Create a state color resolver function that returns a color for a given state string: checks user-configured `stateColors` first, then semantic defaults for common binary pairs (on/off, open/closed, home/away), then falls back to automatic palette assignment
- [x] 3.2 Define a distinguishable automatic color palette (8-10 colors) for states without explicit mappings

## 4. State Timeline Rendering

- [x] 4.1 Create `StateTimelineView` using SwiftUI `GeometryReader` and colored `RoundedRectangle` segments with width proportional to state duration
- [x] 4.2 Add state label text inside segments when width is sufficient, hide when too narrow
- [x] 4.3 Add time axis below the state bars with 3-5 evenly spaced labels
- [x] 4.4 Add compact fallback for small widgets — show current state label with its color instead of full timeline
- [x] 4.5 Add merge logic for very short segments (< 2px) to prevent rendering clutter

## 5. Integration

- [x] 5.1 Add `stateTimeline` case to `PanelRenderer` switch in `PanelCardView.swift`, routing to `StateTimelineView`
- [x] 5.2 Add state timeline to the display style picker in `AddPanelView.swift` (dashboard panels)
- [x] 5.3 Add state timeline to the display style picker in `WidgetItemConfigView.swift` (widget items)
- [x] 5.4 Add state color mapping configuration UI in panel/widget settings when state timeline is selected

## 6. Demo Data

- [x] 6.1 Add state-based demo data to `DemoService` (e.g., door open/closed, HVAC modes) so state timeline can be previewed without a live data source
