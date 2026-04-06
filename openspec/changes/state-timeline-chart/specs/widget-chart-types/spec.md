## MODIFIED Requirements

### Requirement: Widget items support all dashboard display styles
The system SHALL allow widget items to use any display style available to dashboard panels: auto, line, bar, scatter, line+points, single value, gauge, calendar heatmap, calendar heatmap dense, band chart, circular gauge, text, and state timeline.

#### Scenario: Select bar chart for widget item
- **WHEN** user edits a widget item and selects "Bar" as the display style
- **THEN** the widget preview and home screen widget render a bar chart for that item

#### Scenario: Select band chart for widget item
- **WHEN** user edits a widget item and selects "Band" as the display style
- **THEN** the widget renders a band chart with min/max fill area and mean line

#### Scenario: Select calendar heatmap for widget item
- **WHEN** user edits a widget item and selects "Calendar Dense" as the display style
- **THEN** the widget renders a compact calendar heatmap grid

#### Scenario: Select state timeline for widget item
- **WHEN** user edits a widget item and selects "State Timeline" as the display style
- **THEN** the widget renders a state timeline with colored bars for each state

#### Scenario: Display style picker shows all options
- **WHEN** user opens the widget item configuration view
- **THEN** the display style picker shows all available styles with icons, matching the dashboard panel editor
