## ADDED Requirements

### Requirement: Stacked bar display style
The system SHALL provide a `stackedBar` display style that renders multi-series data as stacked bars showing composition over time.

#### Scenario: Multi-series stacked bar
- **WHEN** a panel has multiple series and uses the stacked bar display style
- **THEN** the system renders bars with each series stacked on top of the previous one, with a legend identifying each series

#### Scenario: Single-series fallback
- **WHEN** a panel has only one series and uses the stacked bar display style
- **THEN** the system renders a regular bar chart (stacking has no visual effect with one series)

### Requirement: Stacked area display style
The system SHALL provide a `stackedArea` display style that renders multi-series data as stacked filled areas showing composition over time.

#### Scenario: Multi-series stacked area
- **WHEN** a panel has multiple series and uses the stacked area display style
- **THEN** the system renders filled areas with each series stacked on top of the previous one, with a legend identifying each series

#### Scenario: Single-series fallback
- **WHEN** a panel has only one series and uses the stacked area display style
- **THEN** the system renders a regular area/line chart
