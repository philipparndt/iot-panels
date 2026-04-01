## Context

`StyleConfig` already stores per-panel/item styling as JSON (gauge min/max, heatmap color, band opacity). Colors are currently static — a single color per series. The gauge has built-in color schemes (blueToRed, greenToRed, etc.) that interpolate based on value position within a range, but there's no general-purpose threshold system.

## Goals / Non-Goals

**Goals:**
- Define value thresholds with associated colors (e.g., <15 blue, 15-25 green, >25 red)
- Apply threshold color to single value text, chart lines, and gauge accents
- Simple editor UI to add/remove threshold rules
- Works in both dashboard panels and widget items

**Non-Goals:**
- Animated color transitions between thresholds
- Per-data-point chart coloring (the whole chart uses the color of the latest value)
- Replacing gauge color schemes (thresholds are an alternative, not a replacement)

## Decisions

### 1. Store thresholds in StyleConfig

Add a `thresholds` field to `StyleConfig` as an array of `ThresholdRule` structs:
```
struct ThresholdRule: Codable, Equatable {
    let value: Double    // breakpoint
    let colorHex: String // color to use when value >= this threshold
}
```

Thresholds are sorted ascending by value. The color is determined by finding the last threshold whose value is ≤ the current data value. If the value is below all thresholds, the item's base color is used.

Example: thresholds = [(0, blue), (15, green), (25, red)]
- value 10 → green is NOT reached yet, 0 is → blue
- value 20 → green (15 ≤ 20, but 25 > 20)
- value 30 → red (25 ≤ 30)

### 2. Resolve color in PanelRenderer

Add a `resolvedColor(for value:)` method that checks thresholds. The `primaryColor` computed property uses the latest data value to resolve the color. When thresholds are empty, falls back to `series.first?.color`.

### 3. Simple threshold editor

A list of rows, each with a value text field and a color picker. Add/remove buttons. Sorted ascending on save.

## Risks / Trade-offs

- **[JSON size]** Thresholds add to `styleConfigJSON` → Negligible, typically 2-5 rules.
- **[Chart vs value color]** The chart line uses one color for the entire series (based on latest value), not per-point coloring → Simpler to implement and read. Per-point coloring could be a future enhancement.
- **[Gauge interaction]** When thresholds are set, they override the gauge color scheme → Document this in the UI, or only apply thresholds to non-gauge displays.
