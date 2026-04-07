## ADDED Requirements

### Requirement: State timeline display style
The system SHALL provide a `stateTimeline` display style in `PanelDisplayStyle` that renders discrete string states as colored horizontal bars along a time axis.

#### Scenario: Select state timeline for dashboard panel
- **WHEN** user adds or edits a dashboard panel and selects "State Timeline" as the display style
- **THEN** the panel renders state data as colored horizontal bars with state labels and a time axis

#### Scenario: Select state timeline for widget item
- **WHEN** user selects "State Timeline" as the display style for a widget item
- **THEN** the widget preview and home screen widget render a state timeline for that item

#### Scenario: State timeline with no data
- **WHEN** a state timeline panel has no data points
- **THEN** the panel displays a "No data" placeholder, consistent with other chart types

### Requirement: String state data in ChartDataPoint
The system SHALL support an optional `state: String?` field on `ChartDataPoint` to carry discrete string state values alongside the existing numeric `value` field.

#### Scenario: Numeric data point
- **WHEN** a data point has a numeric value and no state string
- **THEN** the `state` field SHALL be nil and existing chart types render normally

#### Scenario: State data point
- **WHEN** a data point has a non-numeric value from the query result
- **THEN** the parser SHALL populate the `state` field with the string value and set `value` to 0

#### Scenario: Cached data compatibility
- **WHEN** the system decodes cached JSON that was written before the `state` field existed
- **THEN** the `state` field SHALL decode as nil without errors

### Requirement: State-to-color mapping configuration
The system SHALL allow users to configure a mapping of state strings to colors via `StyleConfig`. When no mapping is configured, the system SHALL automatically assign colors from a predefined distinguishable palette.

#### Scenario: Custom color mapping
- **WHEN** user configures a color mapping of "open" → green and "closed" → red
- **THEN** the state timeline renders "open" segments in green and "closed" segments in red

#### Scenario: Automatic color assignment
- **WHEN** no state-color mapping is configured
- **THEN** the system assigns colors from a predefined palette in order of first state appearance

#### Scenario: Semantic defaults for common binary states
- **WHEN** no mapping is configured and the states are a known binary pair (on/off, open/closed, home/away)
- **THEN** the system applies semantic default colors (e.g., green/red) instead of arbitrary palette colors

### Requirement: State timeline rendering
The system SHALL render state segments as colored rounded rectangles with width proportional to the state duration. State labels SHALL appear inside segments when sufficient width is available.

#### Scenario: Wide segment with label
- **WHEN** a state segment is wide enough to fit its label text
- **THEN** the state label text is displayed inside the segment

#### Scenario: Narrow segment without label
- **WHEN** a state segment is too narrow to fit its label text
- **THEN** the label is hidden and only the colored bar is shown

#### Scenario: Time axis display
- **WHEN** a state timeline is rendered
- **THEN** a time axis with 3-5 evenly spaced labels is shown below the state bars

#### Scenario: Compact rendering in small widgets
- **WHEN** a state timeline is rendered in a small iOS widget where the timeline would be unreadable
- **THEN** the system falls back to showing the current state as a label with its mapped color

### Requirement: Query pipeline string value passthrough
The system SHALL detect non-numeric values in query results and route them to the `state` field of `ChartDataPoint` instead of discarding them.

#### Scenario: Non-numeric query result value
- **WHEN** a query returns a row where the value field cannot be parsed as a Double
- **THEN** the value is stored in `ChartDataPoint.state` and `value` is set to 0

#### Scenario: Numeric query result value
- **WHEN** a query returns a row where the value field parses as a Double
- **THEN** the value is stored in `ChartDataPoint.value` and `state` remains nil
