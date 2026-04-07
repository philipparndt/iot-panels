## ADDED Requirements

### Requirement: Sparkline display style
The system SHALL provide a `sparkline` display style that renders a minimal line chart without axes, grid lines, or legends.

#### Scenario: Sparkline rendering
- **WHEN** a panel or widget item uses the sparkline display style with time-series data
- **THEN** the system renders a smooth line showing the trend with no axes, grid, or legend

#### Scenario: Sparkline with last value label
- **WHEN** a sparkline is rendered with available data
- **THEN** the current (last) value SHALL be displayed as a label aligned to the trailing edge of the chart

#### Scenario: Sparkline in compact widget
- **WHEN** a sparkline is rendered in a small iOS widget
- **THEN** the line fills the available space with the value label, optimized for glanceability
