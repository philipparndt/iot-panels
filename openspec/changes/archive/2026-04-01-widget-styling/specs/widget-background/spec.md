## ADDED Requirements

### Requirement: Widget designs have a configurable background color
The system SHALL allow each widget design to have a background color. The default background SHALL be a dark color (#1C1C1E).

#### Scenario: Default background on new widget
- **WHEN** a user creates a new widget design
- **THEN** the background defaults to dark (#1C1C1E)

#### Scenario: Change background color
- **WHEN** user selects a different background color in the widget editor
- **THEN** both the preview and the real home screen widget use the selected background

#### Scenario: Background applies to real widget
- **WHEN** a widget with a custom background is displayed on the home screen
- **THEN** the widget's `.containerBackground` uses the chosen color

### Requirement: Widget editor shows background color picker
The system SHALL provide a background color picker in the widget design editor with preset options and the current selection.

#### Scenario: Select from presets
- **WHEN** user opens the background color section in the widget editor
- **THEN** preset colors are shown (dark, black, system default, light, etc.) and the current selection is highlighted
