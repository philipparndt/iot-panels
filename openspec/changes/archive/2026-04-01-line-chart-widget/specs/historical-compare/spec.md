## ADDED Requirements

### Requirement: Historical comparison overlay
The system SHALL allow any line-based chart panel (line, line+points, band chart) to overlay data from a previous time period for trend comparison.

#### Scenario: Comparison enabled on line chart
- **WHEN** a line chart panel has `comparisonOffset` set to "7d" and the current time range is "Last 7 days"
- **THEN** the chart SHALL display the current period's data as the primary series AND data from 7-14 days ago as a secondary dimmed series, time-aligned to the current period's x-axis

#### Scenario: Comparison on band chart
- **WHEN** a band chart panel has `comparisonOffset` set to "30d"
- **THEN** the chart SHALL display both the current band (min/max/mean) and the comparison period band, with the comparison band rendered at reduced opacity

#### Scenario: Comparison disabled by default
- **WHEN** a panel has no `comparisonOffset` configured (nil)
- **THEN** the chart SHALL render only the current period's data with no comparison overlay

### Requirement: Comparison period configuration
The system SHALL store the comparison period offset on the `DashboardPanel` entity and expose it in the panel editor.

#### Scenario: User configures comparison period
- **WHEN** user opens panel configuration for a line-based chart
- **THEN** the editor SHALL show a "Compare with" picker offering options: None, Same period (auto-matched to time range), and specific offsets (24h, 7d, 14d, 30d, 90d, 365d)

#### Scenario: Comparison offset persisted
- **WHEN** user selects a comparison offset and saves the panel
- **THEN** the `comparisonOffset` value SHALL be persisted on the `DashboardPanel` entity and restored when the panel is loaded

### Requirement: Comparison visual distinction
The comparison overlay data SHALL be visually distinct from the current period data so users can clearly differentiate between them.

#### Scenario: Comparison series styling
- **WHEN** comparison data is rendered alongside current data
- **THEN** the comparison series SHALL use the same color as the primary series but with 0.3 opacity and a dashed line stroke style

#### Scenario: Comparison legend entry
- **WHEN** a panel has comparison enabled and displays a legend
- **THEN** the legend SHALL include an entry for the comparison period (e.g., "Previous 7d") with the dashed/dimmed visual indicator

### Requirement: Comparison query execution
The system SHALL fetch comparison period data by executing a second query with a time-shifted range.

#### Scenario: InfluxDB comparison query
- **WHEN** a comparison-enabled panel queries InfluxDB with time range "Last 7 days" and comparison offset "7d"
- **THEN** the system SHALL execute a second query with range `-14d` to `-7d` and time-shift the results forward by 7 days to align with the primary x-axis

#### Scenario: MQTT comparison data
- **WHEN** a comparison-enabled panel uses an MQTT data source
- **THEN** the system SHALL use locally cached historical data for the comparison period if available, or show only the current period if historical data is insufficient

### Requirement: Comparison not available on non-line charts
The comparison feature SHALL only be available for line-based display styles.

#### Scenario: Comparison hidden for non-line styles
- **WHEN** user views panel configuration for a single value, gauge, bar, scatter, or heatmap panel
- **THEN** the "Compare with" option SHALL NOT be shown in the editor
