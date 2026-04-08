### Requirement: Dashboard panels have a configurable width slot
The system SHALL allow each `DashboardPanel` to declare a width slot of `small`, `medium`, or `full`. The width slot SHALL be persisted on the panel and SHALL default to `full` for any panel that has not set it explicitly (including all pre-existing panels after upgrade).

#### Scenario: Default slot is full
- **WHEN** a new panel is created
- **THEN** its width slot defaults to `full`

#### Scenario: Existing panel after upgrade
- **WHEN** the app is upgraded to the build that introduces width slots
- **THEN** every existing panel renders at full width with no user action required

#### Scenario: Slot persists across launches
- **WHEN** the user sets a panel to `small` and relaunches the app
- **THEN** the panel still has slot `small`

### Requirement: Width slots resolve to a column fraction based on size class
The system SHALL resolve each width slot to a row fraction at render time based on the dashboard's horizontal size class:

| Slot     | Compact (iPhone) | Regular (iPad) |
|----------|------------------|----------------|
| `small`  | 1/2              | 1/4            |
| `medium` | 1/1              | 1/2            |
| `full`   | 1/1              | 1/1            |

#### Scenario: Two small panels share a row on iPhone
- **WHEN** two consecutive `small` panels are shown on a compact-width device
- **THEN** they appear side by side, two per row

#### Scenario: Four small panels share a row on iPad
- **WHEN** four consecutive `small` panels are shown on a regular-width device
- **THEN** they appear side by side, four per row

#### Scenario: Medium panels are full width on iPhone but half on iPad
- **WHEN** two consecutive `medium` panels are shown
- **THEN** on iPhone they appear in two single-panel rows, and on iPad they appear in one row of two

#### Scenario: Full slot is always one per row
- **WHEN** a `full` panel is shown
- **THEN** it spans the entire row on every screen size

### Requirement: Adaptive layout is visible to the user
The system SHALL communicate that the dashboard layout adapts to screen size, so a user moving between iPhone and iPad does not interpret the different arrangement as a bug.

#### Scenario: Picker label shows resolution
- **WHEN** the user opens the width picker for a panel
- **THEN** each option's label includes how it resolves on iPhone and iPad (e.g. "Small — 2 per row on iPhone, 4 per row on iPad")

#### Scenario: Chip shown when adaptive
- **WHEN** the dashboard contains at least one panel whose slot is not `full`
- **THEN** a small "Adaptive layout · iPhone view" or "Adaptive layout · iPad view" chip is visible on the dashboard

#### Scenario: Chip hidden when not adaptive
- **WHEN** every panel on the dashboard has slot `full`
- **THEN** the chip is hidden

#### Scenario: Chip explains the mapping
- **WHEN** the user taps the chip
- **THEN** a popover shows the slot → fraction mapping for the current size class and the alternative size class

### Requirement: Compact display styles allow narrower slots
The system SHALL allow `small` and `medium` slots only for display styles whose rendered content remains legible at narrower widths — at minimum: circular gauge, linear gauge, single value, sparkline, status indicator, state indicator. The system SHALL restrict chart-type display styles (line chart, bar chart, band chart, stacked chart, heatmap, state timeline, table) to `full` slot only.

#### Scenario: Gauge can be small
- **WHEN** the user opens the width picker for a circular gauge panel
- **THEN** `small`, `medium`, and `full` are all selectable

#### Scenario: Line chart cannot be small
- **WHEN** the user opens the width picker for a line chart panel
- **THEN** only `full` is selectable

#### Scenario: Display style change clamps slot
- **WHEN** the user changes a `small` panel's display style to one that does not allow `small`
- **THEN** the panel's slot is clamped to `full` on save

### Requirement: Panels are packed into rows by sort order
The system SHALL render panels in `sortOrder`, packing them into rows by accumulating their resolved row fractions until the next panel would exceed full width, at which point a new row begins. Sort order SHALL remain authoritative for on-screen ordering — packing must never reorder panels.

#### Scenario: Packing respects sort order
- **WHEN** panels with sort order [A, B, C] are rendered
- **THEN** A appears before B, and B before C, regardless of how rows are arranged

#### Scenario: A wider panel forces a new row
- **WHEN** a `full` panel follows a `small` panel on iPhone
- **THEN** the small panel is on its own row (with empty trailing space) and the full panel starts a new row

#### Scenario: Mixed slots pack correctly on iPad
- **WHEN** the sequence on iPad is `small, small, medium, small, small`
- **THEN** the first row is `[small, small, medium]` (1/4 + 1/4 + 1/2 = 1) and the second row is `[small, small]` (1/4 + 1/4 = 1/2)

### Requirement: Panels can force a line break
The system SHALL allow each `DashboardPanel` to set a `lineBreakBefore` flag. When a panel has this flag set, the renderer SHALL close the current row (even if there is remaining capacity) and start a new row before placing that panel. The flag on the first panel of the dashboard SHALL be ignored.

#### Scenario: Line break starts a new row
- **WHEN** two `small` panels are followed by a third `small` panel with `lineBreakBefore = true` on iPad
- **THEN** the first two share a row, and the third starts a new row even though the first row had capacity for two more

#### Scenario: First panel ignores break
- **WHEN** the first panel in `sortOrder` has `lineBreakBefore = true`
- **THEN** the dashboard renders normally with that panel at the top of the first row

#### Scenario: Break is editable
- **WHEN** the user toggles "Break to new row" on a panel
- **THEN** the dashboard re-flows immediately and the new value is persisted

### Requirement: Width and break are editable from the panel's edit sheet and context menu
The system SHALL provide controls to change a panel's width slot and `lineBreakBefore` flag from both the panel's context menu (long-press) on the dashboard and the Edit Panel sheet. The width control SHALL only offer slots allowed by the panel's current display style.

#### Scenario: Change width via context menu
- **WHEN** the user long-presses a panel and selects a new width from the Width submenu
- **THEN** the panel's slot is updated and the dashboard re-flows immediately

#### Scenario: Toggle break via context menu
- **WHEN** the user long-presses a panel and toggles "Break to new row"
- **THEN** the panel's `lineBreakBefore` flag is updated and the dashboard re-flows immediately

#### Scenario: Change width in edit sheet
- **WHEN** the user opens the Edit Panel sheet, changes the width slot, and taps Save
- **THEN** the new slot is persisted

### Requirement: Rearrange mode is unaffected by width
The system SHALL show panels one-per-row in rearrange/edit mode (drag-to-reorder), regardless of width slot. Width affects normal-mode display only. Forced line breaks SHALL be visually indicated in rearrange mode so the user can see which panels begin a new row.

#### Scenario: Rearrange mode is single column
- **WHEN** the user enters rearrange mode on a dashboard whose iPad view shows a row of four `small` panels
- **THEN** those four panels appear as four separate single-column rows in the rearrange list

#### Scenario: Reorder updates sort order
- **WHEN** the user drags a `small` panel above a `full` panel in rearrange mode
- **THEN** the sort order is updated accordingly and on returning to normal mode the small panel renders before the full panel

#### Scenario: Line break is visible in rearrange mode
- **WHEN** a panel has `lineBreakBefore = true` and the user is in rearrange mode
- **THEN** a visual indicator (e.g. a thin divider or break-bar icon) marks that panel as starting a new row

### Requirement: Width and break round-trip through backup/restore
The system SHALL include each panel's width slot and `lineBreakBefore` flag in the JSON backup export and SHALL restore them on import. Backups produced by older builds (with no width slot or break flag) SHALL restore as `full` and `false` respectively.

#### Scenario: Backup includes width and break
- **WHEN** a backup is exported from a dashboard with mixed-width panels and one forced break
- **THEN** each panel's width slot and break flag are included in the JSON

#### Scenario: Restore preserves width and break
- **WHEN** the backup is restored
- **THEN** each panel's width slot and break flag match the original

#### Scenario: Legacy backup defaults
- **WHEN** a backup file produced by a previous build (without the new attributes) is restored
- **THEN** every restored panel has slot `full` and `lineBreakBefore = false`
