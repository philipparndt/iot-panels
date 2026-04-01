## Why

When a widget item uses the single value display style, the text (title, value, unit) is left-aligned via `VStack(alignment: .leading)` in PanelRenderer's `singleValueBody`. This looks off-center in widgets where the item fills the entire cell. Centering the value text improves visual balance, especially for small (2×2) widgets.

## What Changes

- Center-align the single value text in PanelRenderer when `compact` is true (widget context)
- Keep left-alignment for dashboard panels (non-compact) where the card has more context

## Capabilities

### New Capabilities

### Modified Capabilities

## Impact

- **PanelRenderer**: Adjust `singleValueBody` alignment based on `compact` flag
- **Dependencies**: None
