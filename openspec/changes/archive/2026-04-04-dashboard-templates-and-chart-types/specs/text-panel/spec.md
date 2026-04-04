## ADDED Requirements

### Requirement: Text display style
The system SHALL support a `text` panel display style that renders the latest query result value as prominent, centered text.

#### Scenario: Render text panel
- **WHEN** a panel has display style `text`
- **THEN** the system SHALL display the most recent value from the query result as large, centered text

### Requirement: Text panel with unit
If a unit is configured on the query, the text panel SHALL append the unit after the value.

#### Scenario: Display value with unit
- **WHEN** the latest value is "3.5" and the unit is "days"
- **THEN** the text panel SHALL display "3.5 days"

#### Scenario: Display value without unit
- **WHEN** the latest value is "my-hostname" and no unit is configured
- **THEN** the text panel SHALL display "my-hostname"

### Requirement: Text panel formatting
The text panel SHALL format numeric values with appropriate precision (no excessive decimal places) and SHALL display non-numeric strings as-is.

#### Scenario: Numeric value formatting
- **WHEN** the latest value is "86472.123456"
- **THEN** the text panel SHALL display a reasonably rounded value (e.g., "86472")

#### Scenario: String value pass-through
- **WHEN** the latest value is "Ubuntu 22.04"
- **THEN** the text panel SHALL display "Ubuntu 22.04" as-is

### Requirement: Text panel in style picker
The `text` style SHALL appear in the panel display style picker with an appropriate icon and label.

#### Scenario: Select text style
- **WHEN** user opens the display style picker for a panel
- **THEN** "Text" SHALL be available as an option with a text icon

### Requirement: Text panel title
The text panel SHALL display the panel title above the value, providing context for what the value represents.

#### Scenario: Title displayed
- **WHEN** a text panel has title "Uptime" and value "3.5 days"
- **THEN** the panel SHALL show "Uptime" as a header above "3.5 days"
