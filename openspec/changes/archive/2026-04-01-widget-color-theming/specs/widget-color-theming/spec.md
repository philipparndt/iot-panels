## ADDED Requirements

### Requirement: Widget item color is used for single-series charts
The system SHALL use the widget item's configured color for single-series chart rendering (lines, bars, area fill, points) instead of the system accent color.

#### Scenario: Line chart uses item color
- **WHEN** a widget item with color blue renders a single-series line chart
- **THEN** the line and area fill use blue, not the system accent color

### Requirement: Widget item color is used for single value text
The system SHALL use the widget item's configured color for the large value text in single value display mode.

#### Scenario: Single value uses item color
- **WHEN** a widget item with color green renders in single value mode
- **THEN** the value text is displayed in green

### Requirement: Color palette includes white and black
The system SHALL include white (#FFFFFF) and black (#000000) in the series color palette for widget items.

#### Scenario: White color available
- **WHEN** a user opens the widget item color picker
- **THEN** white and black are available as color options
