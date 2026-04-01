## Context

Widget items (groups) are laid out with fixed SwiftUI containers per size type: `HStack` for medium, `VStack` for large. This means medium widgets always show items side-by-side, and large widgets always stack vertically. Neither wraps or uses a grid.

## Goals / Non-Goals

**Goals:**
- Auto-wrap items into a grid based on widget size and item count
- Keep the layout simple and automatic — no user configuration needed
- Same layout in preview and real widget

**Non-Goals:**
- User-configurable column count (keep it automatic)
- Different grid sizes per item (all cells are equal size)

## Decisions

### 1. Grid column count per widget size

Define a `gridColumns` property on `WidgetSizeType`:
- Small: 1 column (always 1 item)
- Medium: items.count columns (1-3 items always fit in 1 row since it's wide)
- Large: 2 columns (items wrap: 1→1×1, 2→2×1, 3→2+1, 4→2×2, 5→2+3, 6→2×3)

### 2. Shared grid view

Create a `WidgetGridLayout` view that takes groups and renders them in a `LazyVGrid` (or manual VStack+HStack grid) with the computed column count. Both `WidgetCanvas` and `WidgetCanvasFromEntry` use this same layout.

**Alternative considered**: `LazyVGrid` — but LazyVGrid needs a fixed height per row which conflicts with `fillHeight`. A manual grid with VStack of HStacks is simpler and gives full control over cell sizing.

### 3. Increase maxCells for large

Change large widget `maxCells` from 4 to 6 to support the 2×3 grid layout.

## Risks / Trade-offs

- **[Compact mode]** With more cells visible, each cell is smaller → Use `compact: true` when cells are small (2+ items in a row). Already handled by existing compact logic.
- **[Odd item counts]** 3 items in a 2-column grid leaves one cell empty → Last row stretches its items to fill width, or the single item takes full width.
