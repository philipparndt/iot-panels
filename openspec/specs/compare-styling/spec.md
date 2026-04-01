## ADDED Requirements

### Requirement: Comparison curves use complementary colors

On all chart types, comparison series SHALL be rendered using a complementary color derived from the primary series color. The complementary color SHALL be computed by rotating the hue by 180° in HSB color space, preserving saturation and brightness.

#### Scenario: Line chart with comparison enabled
- **WHEN** a line chart has comparison mode enabled with any offset
- **THEN** the comparison line SHALL be rendered in the complementary color of the primary series color (not the same color with reduced opacity)

#### Scenario: Band chart with comparison enabled
- **WHEN** a band chart has comparison mode enabled
- **THEN** the comparison mean line SHALL be rendered in the complementary color of the primary series color

#### Scenario: Multiple series with comparison
- **WHEN** a chart has multiple series each with comparison data
- **THEN** each comparison series SHALL use the complementary color of its corresponding primary series color

### Requirement: Band chart comparison shows mean only

On band charts, the comparison overlay SHALL NOT render the min/max area fill (band). Only the mean line SHALL be displayed for the comparison period.

#### Scenario: Band chart comparison rendering
- **WHEN** a band chart renders comparison data from a previous period
- **THEN** the comparison band area fill (AreaMark between min and max) SHALL NOT be rendered
- **AND** the comparison mean line SHALL be rendered with a dashed line style

#### Scenario: Primary band unaffected
- **WHEN** a band chart has comparison mode enabled
- **THEN** the primary period's band (min/max area fill) and mean line SHALL continue to render normally
