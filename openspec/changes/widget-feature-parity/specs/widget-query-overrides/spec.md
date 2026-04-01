## ADDED Requirements

### Requirement: Widget items support per-item time range override
The system SHALL allow each widget item to override the saved query's default time range. When no override is set, the saved query's time range SHALL be used.

#### Scenario: Set custom time range on widget item
- **WHEN** user sets a widget item's time range to "Last 30 days"
- **THEN** the widget fetches data for the last 30 days, regardless of the saved query's default time range

#### Scenario: No time range override uses query default
- **WHEN** a widget item has no time range override set
- **THEN** the widget uses the saved query's configured time range

### Requirement: Widget items support per-item aggregation overrides
The system SHALL allow each widget item to override the saved query's default aggregate window and aggregate function.

#### Scenario: Set custom aggregation on widget item
- **WHEN** user sets a widget item's aggregate window to "1 hour" and function to "Max"
- **THEN** the widget query uses 1-hour max aggregation instead of the saved query's defaults

#### Scenario: Aggregation window filtered by time range
- **WHEN** user selects a time range for a widget item
- **THEN** the aggregation window picker only shows windows appropriate for that time range

### Requirement: Widget items support comparison overlays
The system SHALL allow widget items with line-based display styles to configure a comparison offset, showing historical data overlaid on the current period.

#### Scenario: Enable comparison on widget item
- **WHEN** user sets a comparison period of "Last year" on a line chart widget item
- **THEN** the widget renders data from a year ago as a dashed overlay alongside current data

#### Scenario: Comparison not available for non-line styles
- **WHEN** a widget item uses single value or gauge display style
- **THEN** the comparison offset setting SHALL not be shown

### Requirement: Widget item editor exposes query override settings
The system SHALL show time range, aggregation window, aggregation function, and comparison offset pickers in the widget item configuration view, matching the dashboard panel editor's data section.

#### Scenario: Edit widget item query settings
- **WHEN** user opens the widget item configuration view
- **THEN** pickers for time range, aggregation window, aggregation function, and comparison period are visible
