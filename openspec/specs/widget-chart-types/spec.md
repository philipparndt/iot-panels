## MODIFIED Requirements

### Requirement: Widget items support all dashboard display styles
The system SHALL allow widget items to use any display style available to dashboard panels: auto, line, bar, scatter, line+points, single value, gauge, calendar heatmap, calendar heatmap dense, band chart, circular gauge, text, sparkline, stacked bar, stacked area, status indicator, and table.

#### Scenario: Select bar chart for widget item
- **WHEN** user edits a widget item and selects "Bar" as the display style
- **THEN** the widget preview and home screen widget render a bar chart for that item

#### Scenario: Select band chart for widget item
- **WHEN** user edits a widget item and selects "Band" as the display style
- **THEN** the widget renders a band chart with min/max fill area and mean line

#### Scenario: Select calendar heatmap for widget item
- **WHEN** user edits a widget item and selects "Calendar Dense" as the display style
- **THEN** the widget renders a compact calendar heatmap grid

#### Scenario: Select sparkline for widget item
- **WHEN** user edits a widget item and selects "Sparkline" as the display style
- **THEN** the widget renders a minimal trend line with last value label

#### Scenario: Select stacked bar for widget item
- **WHEN** user edits a widget item and selects "Stacked Bar" as the display style
- **THEN** the widget renders stacked bars for multi-series data

#### Scenario: Select status indicator for widget item
- **WHEN** user edits a widget item and selects "Status" as the display style
- **THEN** the widget renders a colored status circle with value

#### Scenario: Select table for widget item
- **WHEN** user edits a widget item and selects "Table" as the display style
- **THEN** the widget renders a compact table with recent data rows

#### Scenario: Display style picker shows all options
- **WHEN** user opens the widget item configuration view
- **THEN** the display style picker shows all available styles with icons, matching the dashboard panel editor
