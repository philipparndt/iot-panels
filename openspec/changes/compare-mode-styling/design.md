## Context

The compare mode overlays a previous period's data on top of the current chart. Currently, comparison series use the same color as the primary series with reduced opacity (0.3), and band charts render the full min/max area fill for both primary and comparison data. This creates visual clutter, especially on band charts where two overlapping bands are hard to read.

Key files:
- `PanelCardView.swift`: Renders charts, builds comparison band groups, assigns series colors
- `ColorUtilities.swift`: Hex color parsing and series color palette

## Goals / Non-Goals

**Goals:**
- On band charts, comparison overlay shows only the mean line (no area fill between min/max)
- On all chart types, comparison curves use a complementary color for clear visual distinction

**Non-Goals:**
- Changing primary series colors or band rendering
- Adding user-configurable comparison colors (use computed complementary colors)
- Modifying comparison data fetching or query logic

## Decisions

### 1. Complementary color computation

Use HSB (Hue-Saturation-Brightness) color space to compute complementary colors by rotating hue by 180°. This guarantees maximum visual contrast between primary and comparison series.

**Rationale**: HSB hue rotation is the standard approach for complementary colors and works well with any base color. It's simple to implement in SwiftUI using `Color` → `UIColor` → HSB components → rotated `Color`.

**Alternative considered**: Using a fixed comparison color palette — rejected because it wouldn't adapt to custom series colors or the accent color.

### 2. Skip comparison band area fill

In the band chart rendering loop, simply skip `AreaMark` rendering for comparison band groups while keeping the mean `LineMark` with dashed style.

**Rationale**: Minimal code change — the comparison band groups are already identified separately in the rendering code. We just need to conditionally skip the area fill portion.

## Risks / Trade-offs

- [Complementary of certain colors may have low contrast against chart background] → Both light and dark mode backgrounds are neutral, so hue-rotated colors should remain visible. The existing brightness/saturation is preserved.
- [Removing comparison band area removes min/max context] → This is the intended behavior per requirements. The mean line still shows the trend, which is sufficient for comparison purposes.
