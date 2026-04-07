## ADDED Requirements

### Requirement: Chart types are grouped by category
The system SHALL assign each `PanelDisplayStyle` to a category. Categories SHALL be: Time Series, Values, Grid, and Other. Categories SHALL be displayed in this order.

#### Scenario: Line chart category
- **WHEN** the system resolves the category for the line, bar, scatter, line+points, and band display styles
- **THEN** they SHALL all belong to the "Time Series" category

#### Scenario: Value chart category
- **WHEN** the system resolves the category for single value, gauge, and circular gauge display styles
- **THEN** they SHALL all belong to the "Values" category

#### Scenario: Grid chart category
- **WHEN** the system resolves the category for calendar heatmap and calendar heatmap dense display styles
- **THEN** they SHALL all belong to the "Grid" category

#### Scenario: Other category
- **WHEN** the system resolves the category for auto and text display styles
- **THEN** they SHALL belong to the "Other" category

### Requirement: Sectioned display style picker in dashboard panels
The system SHALL display chart types grouped by category with section headers in the dashboard panel display style picker.

#### Scenario: Dashboard panel picker shows sections
- **WHEN** user opens the display style picker when adding or editing a dashboard panel
- **THEN** the picker shows chart types grouped under category section headers with icons and display names

#### Scenario: Section order
- **WHEN** the sectioned picker is displayed
- **THEN** sections appear in order: Time Series, Values, Grid, Other

### Requirement: Sectioned display style picker in widget items
The system SHALL display chart types grouped by category with section headers in the widget item display style picker.

#### Scenario: Widget item picker shows sections
- **WHEN** user opens the display style picker when editing a widget item
- **THEN** the picker shows chart types grouped under category section headers, matching the dashboard panel picker layout

### Requirement: New chart types automatically categorized
The system SHALL require every new `PanelDisplayStyle` case to have a category assignment, ensuring new types always appear in an appropriate section.

#### Scenario: Adding a new display style
- **WHEN** a new case is added to `PanelDisplayStyle`
- **THEN** the `category` computed property SHALL include a case for it (enforced by exhaustive switch)
