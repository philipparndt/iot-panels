## ADDED Requirements

### Requirement: Background sparkline toggle
The system SHALL support a `showTrendLine` boolean field in `StyleConfig` that controls whether a background sparkline is rendered behind the panel content.

#### Scenario: Trend line disabled by default
- **WHEN** a panel has `showTrendLine` as nil or false
- **THEN** no background sparkline SHALL be rendered

#### Scenario: Trend line enabled
- **WHEN** a panel has `showTrendLine` set to true
- **THEN** a filled area sparkline SHALL be rendered behind the panel's primary content

### Requirement: Supported panel types
The background sparkline SHALL be available for the `singleValue` and `circularGauge` display styles.

#### Scenario: Single value with trend line
- **WHEN** a `singleValue` panel has `showTrendLine` enabled and data points are available
- **THEN** a filled area sparkline SHALL appear behind the value text

#### Scenario: Circular gauge with trend line
- **WHEN** a `circularGauge` panel has `showTrendLine` enabled and data points are available
- **THEN** a filled area sparkline SHALL appear behind the gauge ring, clipped to a circle

#### Scenario: Unsupported panel type
- **WHEN** a panel with display style other than `singleValue` or `circularGauge` has `showTrendLine` set to true
- **THEN** the setting SHALL be ignored and no background sparkline SHALL be rendered

### Requirement: Sparkline rendering style
The background sparkline SHALL render as a filled area chart (line with fill to bottom edge) with no axes, labels, or grid lines. The fill SHALL use a semi-transparent version of the panel's accent color.

#### Scenario: Visual appearance
- **WHEN** the background sparkline is rendered
- **THEN** it SHALL display as a smooth filled area with low opacity that does not obscure the primary panel content

### Requirement: Configurable Y-axis range
The system SHALL support `trendMin` and `trendMax` optional Double fields in `StyleConfig` for defining the Y-axis range of the background sparkline.

#### Scenario: Custom range
- **WHEN** `trendMin` is 10 and `trendMax` is 50
- **THEN** the sparkline Y-axis SHALL span from 10 to 50, clipping values outside this range

#### Scenario: Auto range from data
- **WHEN** `trendMin` and `trendMax` are nil and the unit is not `%`
- **THEN** the sparkline Y-axis range SHALL be derived from the minimum and maximum values in the data

#### Scenario: Auto range for percentage unit
- **WHEN** `trendMin` and `trendMax` are nil and the unit is `%`
- **THEN** the sparkline Y-axis range SHALL default to 0–100

### Requirement: Trend line configuration UI
The panel configuration UI SHALL show a "Trend Line" section for `singleValue` and `circularGauge` panels, containing a toggle and optional min/max range fields.

#### Scenario: Toggle visibility
- **WHEN** the user opens the config for a `singleValue` or `circularGauge` panel
- **THEN** a "Trend Line" toggle SHALL be displayed

#### Scenario: Range fields shown when enabled
- **WHEN** the user enables the trend line toggle
- **THEN** optional "Min" and "Max" text fields SHALL appear for configuring the Y-range

#### Scenario: Range fields hidden when disabled
- **WHEN** the trend line toggle is off
- **THEN** the min/max range fields SHALL NOT be displayed

### Requirement: Data source for sparkline
The background sparkline SHALL use all data points from the first series of the panel's data.

#### Scenario: Single series
- **WHEN** a panel has one data series with 50 data points
- **THEN** the sparkline SHALL render all 50 data points

#### Scenario: Multi-series
- **WHEN** a panel has multiple data series
- **THEN** the sparkline SHALL use data points from the first series only
