## Why

As IoT Panels adds more chart types (state timeline, sparkline, stacked charts, status indicators), the flat list of display styles in the panel/widget pickers becomes unwieldy. Grouping chart types into logical sections makes it easier for users to find the right visualization and understand what each category offers.

## What Changes

- Add a `category` property to `PanelDisplayStyle` that groups each style into a section (Time Series, State/Status, Values, Grid/Table, Other)
- Replace the flat style picker in `AddPanelView` and `WidgetItemConfigView` with a sectioned list showing styles grouped by category with section headers
- Add small static preview icons or thumbnails per chart type to make the picker more visual and scannable

## Capabilities

### New Capabilities
- `chart-type-sections`: Categorization of display styles and sectioned picker UI for selecting chart types in dashboard panels and widget items

### Modified Capabilities
None — this is a UI reorganization that doesn't change the behavior of existing chart type specs.

## Impact

- `PanelDisplayStyle` enum gains a `category` computed property
- `AddPanelView.swift` picker UI changes from flat to sectioned
- `WidgetItemConfigView.swift` picker UI changes from flat to sectioned
- No data model changes, no query pipeline changes
