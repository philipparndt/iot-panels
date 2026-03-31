## Why

The compare mode overlay is visually noisy on band charts — showing both the primary and comparison bands creates clutter that makes it hard to read the actual data. Additionally, comparison curves on all chart types use the same color with reduced opacity, making them hard to distinguish from the primary series.

## What Changes

- **Band chart compare mode**: Remove the band (min/max area fill) for the comparison period. Only render the mean line (dashed) so the primary band remains clearly readable.
- **Comparison curve colors**: On all chart types, render comparison curves in a complementary color instead of the same series color with reduced opacity. This provides clear visual distinction between primary and comparison data.

## Capabilities

### New Capabilities
- `compare-styling`: Improved visual styling for comparison overlays — complementary colors and band-only-mean rendering

### Modified Capabilities

## Impact

- `PanelCardView.swift`: Comparison band rendering logic (skip area marks for comparison groups), comparison series color assignment
- `ColorUtilities.swift`: Add complementary color computation utility
