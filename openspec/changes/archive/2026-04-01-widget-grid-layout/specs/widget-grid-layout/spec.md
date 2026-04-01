## ADDED Requirements

### Requirement: Widget items are laid out in an auto-grid
The system SHALL lay out widget items in a grid that automatically wraps into rows and columns based on widget size.

#### Scenario: Small widget layout
- **WHEN** a small (2×2) widget has 1 item
- **THEN** the item fills the entire widget

#### Scenario: Medium widget with 2 items
- **WHEN** a medium (4×2) widget has 2 items
- **THEN** items are displayed in 2 columns in a single row

#### Scenario: Medium widget with 3 items
- **WHEN** a medium (4×2) widget has 3 items
- **THEN** items are displayed in 3 columns in a single row

#### Scenario: Large widget with 2 items
- **WHEN** a large (4×4) widget has 2 items
- **THEN** items are displayed in 2 columns in a single row

#### Scenario: Large widget with 4 items
- **WHEN** a large (4×4) widget has 4 items
- **THEN** items are displayed in a 2×2 grid (2 columns, 2 rows)

#### Scenario: Large widget with 3 items
- **WHEN** a large (4×4) widget has 3 items
- **THEN** 2 items are in the first row and 1 item fills the full width of the second row

#### Scenario: Large widget with 6 items
- **WHEN** a large (4×4) widget has 6 items
- **THEN** items are displayed in a 2×3 grid (2 columns, 3 rows)

### Requirement: Preview and real widget use the same grid layout
The system SHALL render the same grid layout in the in-app preview and the real home screen widget.

#### Scenario: Matching layout
- **WHEN** a widget design is previewed in the app and displayed on the home screen
- **THEN** both use the same grid arrangement for the same items
