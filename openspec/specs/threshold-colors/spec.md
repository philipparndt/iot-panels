## ADDED Requirements

### Requirement: Users can define color thresholds based on value ranges
The system SHALL allow users to define an ordered list of threshold rules, each with a value breakpoint and a color. The display color SHALL be determined by the highest threshold whose value is less than or equal to the current data value.

#### Scenario: Value below first threshold
- **WHEN** thresholds are [(15, green), (25, red)] and the current value is 10
- **THEN** the item's base color is used (no threshold matched)

#### Scenario: Value matches a threshold
- **WHEN** thresholds are [(15, green), (25, red)] and the current value is 20
- **THEN** the display color is green (15 ≤ 20 < 25)

#### Scenario: Value above all thresholds
- **WHEN** thresholds are [(15, green), (25, red)] and the current value is 30
- **THEN** the display color is red (25 ≤ 30)

#### Scenario: No thresholds configured
- **WHEN** no threshold rules are defined
- **THEN** the item's base color or accent color is used (unchanged behavior)

### Requirement: Threshold color applies to single value display
The system SHALL use the threshold-resolved color for the large value text in single value mode.

#### Scenario: Single value with threshold
- **WHEN** a single value item shows 28°C with thresholds [(20, green), (25, red)]
- **THEN** the value text is displayed in red

### Requirement: Threshold color applies to charts
The system SHALL use the threshold-resolved color (based on the latest data point) for single-series chart rendering.

#### Scenario: Line chart with threshold
- **WHEN** a line chart's latest value is 22 with thresholds [(20, green), (25, red)]
- **THEN** the chart line and fill use green

### Requirement: Threshold editor in panel and widget config
The system SHALL provide a threshold editor in both `EditPanelView` and `WidgetItemConfigView` where users can add, edit, and remove threshold rules.

#### Scenario: Add a threshold rule
- **WHEN** user taps "Add Threshold" and enters value 25 with color red
- **THEN** a new threshold rule is added and the preview updates

#### Scenario: Remove a threshold rule
- **WHEN** user removes a threshold rule
- **THEN** the rule is deleted and the preview updates
