## ADDED Requirements

### Requirement: Band chart display style
The system SHALL provide a `bandChart` display style in `PanelDisplayStyle` that renders a filled area between min and max aggregate values with a solid mean line overlay.

#### Scenario: Band chart renders min/max area with mean line
- **WHEN** a panel is configured with `bandChart` display style and has data points
- **THEN** the chart SHALL render an `AreaMark` filled between the min and max aggregated values, and a `LineMark` showing the mean aggregated value on top

#### Scenario: Band chart with no data
- **WHEN** a panel is configured with `bandChart` display style and has no data points
- **THEN** the chart SHALL display the standard empty state (same as other chart types)

### Requirement: Multi-aggregate query for band chart
The system SHALL fetch min, max, and mean aggregate values simultaneously when a panel uses the `bandChart` display style, regardless of the panel's `aggregateFunction` setting.

#### Scenario: InfluxDB multi-aggregate query
- **WHEN** a band chart panel queries an InfluxDB data source with a configured aggregate window
- **THEN** the system SHALL generate a Flux query that returns three series per field: `<field>_min`, `<field>_max`, and `<field>_mean`, each aggregated over the configured window

#### Scenario: MQTT local aggregation
- **WHEN** a band chart panel uses an MQTT data source
- **THEN** the system SHALL compute min, max, and mean aggregates locally from the available cached data points, grouped by the configured aggregate window

#### Scenario: Band chart ignores panel aggregate function
- **WHEN** a panel has `aggregateFunction` set to `last` but display style is `bandChart`
- **THEN** the system SHALL query min, max, and mean regardless, ignoring the `last` setting

### Requirement: Band chart styling configuration
The system SHALL allow configuration of band chart visual properties through `StyleConfig`.

#### Scenario: Default band styling
- **WHEN** a band chart panel has no custom style configuration
- **THEN** the band area SHALL use the series accent color at 0.2 opacity, and the mean line SHALL use the series accent color at full opacity

#### Scenario: Custom band opacity
- **WHEN** `StyleConfig.bandOpacity` is set to a value (e.g., 0.4)
- **THEN** the band area fill SHALL use that opacity value

#### Scenario: Custom band color
- **WHEN** `StyleConfig.bandColor` is set to a color value
- **THEN** the band area and mean line SHALL use that color instead of the series accent color

### Requirement: Band chart in panel editor
The system SHALL include `bandChart` as a selectable option in the panel display style picker, with an appropriate icon and display name.

#### Scenario: Band chart appears in style picker
- **WHEN** user opens the panel configuration and views available display styles
- **THEN** "Band" SHALL appear in the list with a recognizable chart icon

#### Scenario: Band chart requires aggregate window
- **WHEN** user selects `bandChart` display style and aggregate window is set to "None (raw)"
- **THEN** the system SHALL automatically select the minimum recommended window for the current time range
