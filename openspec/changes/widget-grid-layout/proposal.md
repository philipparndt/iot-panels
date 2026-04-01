## Why

Widget layouts are currently fixed: small shows 1 item, medium shows items in a horizontal row, large shows items in a vertical stack. This limits design flexibility — a large (4×4) widget with 4 items can only stack them vertically, wasting horizontal space. Users want items to automatically wrap into a grid (e.g., 2×2 in a large widget) for better use of space.

## What Changes

- Replace fixed HStack/VStack layouts with an auto-grid that wraps items into rows based on the widget size
- Small (2×2): 1 column, 1 item (unchanged)
- Medium (4×2): up to 3 columns in 1 row, or 2+1 wrapping for 3 items
- Large (4×4): 2 columns × 2 rows grid, accommodating up to 4 items
- Increase maxCells for large widgets to support more items in the grid
- Apply the same grid layout in both `WidgetCanvas` (preview) and `WidgetCanvasFromEntry` (real widget)

## Capabilities

### New Capabilities
- `widget-grid-layout`: Auto-grid layout for widget items that wraps into rows and columns based on widget size

### Modified Capabilities

## Impact

- **WidgetDesignPreviewView**: Replace HStack/VStack per size with a shared grid layout
- **IoTPanelsWidget (WidgetCanvasFromEntry)**: Same grid layout change
- **WidgetSizeType**: Update `maxCells` for large to support more items, add grid column count per size
- **Dependencies**: None
