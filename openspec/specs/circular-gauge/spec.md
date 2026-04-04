## ADDED Requirements

### Requirement: Circular gauge display style
The system SHALL support a `circularGauge` panel display style that renders a radial ring gauge showing the current value as a filled arc.

#### Scenario: Render circular gauge
- **WHEN** a panel has display style `circularGauge`
- **THEN** the system SHALL render a circular ring gauge with the current value displayed in the center

### Requirement: Circular gauge uses StyleConfig
The circular gauge SHALL use the same `StyleConfig` properties as the existing slider gauge:
- `gaugeMin` / `gaugeMax` for range (auto-calculated from data if nil)
- `gaugeColorScheme` for gradient colors

#### Scenario: Configured min/max
- **WHEN** gaugeMin is 0 and gaugeMax is 100
- **THEN** the circular gauge SHALL use 0–100 as the range

#### Scenario: Auto range
- **WHEN** gaugeMin and gaugeMax are nil
- **THEN** the circular gauge SHALL auto-calculate the range from the data with 10% padding

### Requirement: Circular gauge color
The circular gauge ring fill color SHALL be derived from the configured `GaugeColorScheme`, interpolated based on the current value's position between min and max.

#### Scenario: Color at midpoint
- **WHEN** the value is at 50% of the range with a blueToRed scheme
- **THEN** the ring fill color SHALL be the interpolated color at the midpoint of the gradient

### Requirement: Circular gauge in style picker
The `circularGauge` style SHALL appear in the panel display style picker with an appropriate icon and label.

#### Scenario: Select circular gauge style
- **WHEN** user opens the display style picker for a panel
- **THEN** "Circular Gauge" SHALL be available as an option with a circular gauge icon

### Requirement: Circular gauge multi-series
When multiple series are present, the circular gauge SHALL display the last value of the first series in the ring, with a legend listing all series values below.

#### Scenario: Multi-series circular gauge
- **WHEN** a circular gauge panel has 3 data series
- **THEN** the ring SHALL show the first series value and a legend SHALL list all 3 series with their values
