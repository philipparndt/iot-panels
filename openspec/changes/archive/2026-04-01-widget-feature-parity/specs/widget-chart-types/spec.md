## ADDED Requirements

### Requirement: Widget items support all dashboard display styles
The system SHALL allow widget items to use any display style available to dashboard panels: auto, line, bar, scatter, line+points, single value, gauge, calendar heatmap, calendar heatmap dense, and band chart.

#### Scenario: Select bar chart for widget item
- **WHEN** user edits a widget item and selects "Bar" as the display style
- **THEN** the widget preview and home screen widget render a bar chart for that item

#### Scenario: Select band chart for widget item
- **WHEN** user edits a widget item and selects "Band" as the display style
- **THEN** the widget renders a band chart with min/max fill area and mean line

#### Scenario: Select calendar heatmap for widget item
- **WHEN** user edits a widget item and selects "Calendar Dense" as the display style
- **THEN** the widget renders a compact calendar heatmap grid

#### Scenario: Display style picker shows all options
- **WHEN** user opens the widget item configuration view
- **THEN** the display style picker shows all available styles with icons, matching the dashboard panel editor

### Requirement: Band chart style configuration in widgets
The system SHALL allow widget items with band chart style to configure band opacity, matching the dashboard panel editor.

#### Scenario: Configure band opacity
- **WHEN** user selects band chart style for a widget item
- **THEN** a band opacity configuration option appears in the item settings

### Requirement: Heatmap color configuration in widgets
The system SHALL allow widget items with calendar heatmap styles to configure the heatmap color scheme.

#### Scenario: Configure heatmap color
- **WHEN** user selects a calendar heatmap style for a widget item
- **THEN** a heatmap color picker appears in the item settings
