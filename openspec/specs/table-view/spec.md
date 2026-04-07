## ADDED Requirements

### Requirement: Table display style
The system SHALL provide a `table` display style that renders query result data in a tabular format with columns for time, field, and value.

#### Scenario: Table rendering with numeric data
- **WHEN** a panel uses the table display style with numeric time-series data
- **THEN** the system displays rows with Time, Field, and Value columns

#### Scenario: Table rendering with state data
- **WHEN** a panel uses the table display style with string state data
- **THEN** the system displays rows with Time, Field, and State columns

#### Scenario: Table scrolling
- **WHEN** the query result has more rows than fit in the panel height
- **THEN** the table is scrollable within the panel bounds

#### Scenario: Table in small widget
- **WHEN** a table is rendered in a small iOS widget
- **THEN** the system shows only the most recent 2-3 rows to fit the constrained space
