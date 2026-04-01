## ADDED Requirements

### Requirement: Preview and real widget have matching layout
The system SHALL use the same padding and layout structure for the in-app widget preview and the real home screen widget so the preview is WYSIWYG.

#### Scenario: Chart size matches between preview and home screen
- **WHEN** a user designs a widget in the editor and adds it to their home screen
- **THEN** the chart proportions, padding, and overall appearance match the preview

#### Scenario: Shared rendering code
- **WHEN** the preview or real widget renders a group cell
- **THEN** both use the same rendering view/function with the same parameters
