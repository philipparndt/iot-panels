## ADDED Requirements

### Requirement: Status indicator display style
The system SHALL provide a `statusIndicator` display style that renders a colored circle with the current value and an optional label, representing at-a-glance health status.

#### Scenario: Status with threshold colors
- **WHEN** a panel uses the status indicator display style and has threshold rules configured
- **THEN** the circle color reflects the threshold rule matching the current value

#### Scenario: Status without thresholds
- **WHEN** a panel uses the status indicator display style with no threshold rules
- **THEN** the circle uses the panel's accent color

#### Scenario: Status indicator layout
- **WHEN** a status indicator is rendered in a dashboard panel
- **THEN** it displays a large centered colored circle with the current value and field name

#### Scenario: Status indicator in widget
- **WHEN** a status indicator is rendered in an iOS widget
- **THEN** it displays a compact colored circle with the value inline
