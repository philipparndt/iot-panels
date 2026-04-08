## Context

`DashboardView.swift` currently renders panels with:

```swift
LazyVStack(spacing: 16) {
    ForEach(panels, id: \.objectID) { panel in
        PanelCardView(panel: panel)
    }
}
```

Every panel is one row. There is no concept of width: `PanelCardView` always expands to the full available width via `.frame(maxWidth: .infinity)` patterns inside it. The data model has `DashboardPanel.sortOrder` (Int32) and that is the only thing that controls layout.

`PanelCardView` already adapts its content to the width it's given (it uses `GeometryReader` for the chart styles), so it can in principle render at half width. The display styles that would benefit most from being narrower are: circular gauge, linear gauge, single value, sparkline, status indicator, state indicator. Charts (line, bar, band, heatmap) usually want full width to be readable.

`PanelDisplayStyle` already exists with categories (the `grouped()` helper used in the context menu), so we have a clean place to ask "is this style compact-friendly?".

## Goals / Non-Goals

**Goals:**
- Let the user place multiple compact panels in the same row.
- Keep the data model change minimal (one attribute on `DashboardPanel`).
- Preserve existing dashboards: any panel that does not specify a width is rendered at full width.
- Keep rearrange/drag-to-reorder working — width is *display*, sort order is still the authoritative ordering.
- Backup/restore round-trips the new attribute.

**Non-Goals:**
- Free-form drag-and-drop grid (the user did not ask for this; it would be a much bigger UI overhaul).
- Per-panel height. Panel height is still driven by the display style.
- Responsive width that depends on device class. iPad and iPhone use the same fractions for now; the row simply has more pixels on iPad.
- Mixing arbitrary fraction values (e.g. 1/4 + 3/4). Only a small fixed set of fractions is supported initially.

## Decisions

### D1: Three adaptive size slots — small, medium, full

A `DashboardPanel.widthSlot` attribute stores one of: `"small"`, `"medium"`, `"full"`. The slot is *not* a fixed fraction. It is resolved to a column span at render time based on the dashboard's horizontal size class:

| Slot | compact (iPhone) | regular (iPad) |
|------|------------------|----------------|
| `small`  | ½ row (2 per row) | ¼ row (4 per row) |
| `medium` | full row | ½ row (2 per row) |
| `full`   | full row | full row |

**Why:** This is the minimum-attribute design that solves both the iPhone problem ("I want two gauges per row") and the iPad problem ("the dashboard wastes half the screen") with one user-visible knob. The user picks intent ("this is a small panel") and the layout figures out the right column count for the device.

**Alternatives considered:**
- *Fixed fractions (full/half/third).* Original proposal. Doesn't help iPad — a "half" panel on iPad is still 500+ points wide. Forces the user to think about exact fractions even though they really mean "compact" or "wide".
- *Explicit column spans (1/2/4) with explicit total column counts per device.* More expressive but requires the user to understand a grid model and pick numbers per device. Worse UX for the same outcome.
- *Auto-pick based on display style only (no per-panel knob).* Tempting but takes away user control: a sparkline that the user really wants to feature should still be allowed to take a full row.
- *Continuous size slider.* Rejected — predictability is worth more than expressiveness for v1.

### D1a: Make the adaptive layout visible to the user

Adaptive layout has a known UX failure mode: a user creates a dashboard on iPhone, opens it on iPad, sees a different arrangement, and concludes the layout is broken or that sync corrupted their panels. The mitigation is to make the adaptiveness explicit *both* in the picker (so the user understands what they're choosing) *and* on the dashboard (so the user understands what they're seeing).

**Picker labels show the resolution.** The width picker doesn't say "Small". It says:

```
Small        — 2 per row on iPhone, 4 per row on iPad
Medium       — 1 per row on iPhone, 2 per row on iPad
Full width   — 1 per row everywhere
```

The mapping is part of the label, so the user can never be surprised by what `small` means on the other device.

**A small footer chip on the dashboard.** Below the navigation title (or at the bottom of the panel list), a one-line dimmed chip says:

> "Adaptive layout · iPhone view"  /  "Adaptive layout · iPad view"

It is unobtrusive but visible. Tapping it opens a small popover that explains the slot → columns mapping for the current screen and shows the alternative for the other size class. If the user has only ever set panels to `full`, the chip is hidden — there is nothing adaptive happening.

**No silent reordering across devices.** Sort order is the only thing that determines panel order. On iPad, packing more panels per row never *reorders* them — it only puts the same sequence in fewer, wider rows. The user's "panel 5 is below panel 4" invariant always holds.

**Why:** Predictability and discoverability are both required. The label-with-resolution pattern means the user never has to guess what a slot does. The chip means a confused user has somewhere obvious to look. The sort-order invariant means even when the layout reflows, panels never *swap*, they just regroup.

### D2: Row packing by sort order, with explicit line breaks

The renderer walks panels in `sortOrder` and accumulates them into rows. Each row has a remaining capacity of 1.0 (full). Adding a panel of fraction `w` reduces capacity by `w`; if the next panel doesn't fit, it starts a new row. This is equivalent to a single-pass first-fit-by-order packer.

In addition, each `DashboardPanel` has a boolean `lineBreakBefore` attribute (default `false`). When the packer encounters a panel with `lineBreakBefore == true`, it closes the current row (even if there is still capacity) and starts a new row before placing that panel. This gives the user explicit visual grouping when packing alone is not enough — for example, "two gauges, then a forced break, then another two gauges" reads as two distinct pairs even though all four would otherwise fit on one wide row on iPad.

The break is stored on the *following* panel ("break before me"), not the preceding one, because that makes drag-to-reorder intuitive: when the user moves a panel, its break marker moves with it, so the same panel always begins its row. The first panel in a dashboard ignores its `lineBreakBefore` flag (there is no row to break from).

**Why:** Predictable. The user controls layout entirely by sort order + width. No surprise rearrangements when content changes. Matches the mental model of "I dragged this panel here and made it half-width, now it sits next to the previous panel".

**Alternatives considered:**
- *Best-fit (search forward to fill gaps).* Would let a later half-width panel jump up to fill a hole. Rejected — visually jarring and breaks the connection between sort order and on-screen order.
- *CSS-flexbox style with explicit row breaks.* Adds another model attribute and another UI affordance. Not worth it for the small set of fractions.

### D3: Storage as a String enum, not Int

The attribute is `widthSlot: String?` with values `"small" | "medium" | "full"`. A wrapped Swift enum (`PanelWidthSlot`) decodes it.

**Why:** Matches the existing project pattern (`displayStyle`, `timeRange`, `aggregateWindow` are all stored as `String?`). Migrations are trivial — old rows have `nil` and the wrapper interprets `nil` as `.full`. CloudKit-friendly (just a string attribute). Crucially: the slot is *intent*, not *measurement* — what's stored is "the user wants this to be small", not "this should be 240 points wide". The render layer is free to evolve the resolution table without re-migrating data.

### D4: Restrict the picker to display styles that look acceptable when narrow

The width picker is shown for **all** panels, but the available slots depend on the display style. Chart-type styles (line/bar/band/stacked/heatmap/state timeline/table) can pick `full` only. Compact styles (circular gauge, linear gauge, single value, sparkline, status indicator, value-only) can pick `small`, `medium`, or `full`. Exposed via `PanelDisplayStyle.allowedWidthSlots`.

**Why:** A circular gauge at ¼ width on iPad (≈180pt) is fine. A heatmap at ¼ width is unreadable noise. Restricting at the source prevents broken layouts. If the user changes the display style of an existing `small` panel to a chart, the value gracefully clamps to `full` on save (and the picker reflects that immediately).

### D5: Render with a custom flow layout that observes the size class

Use SwiftUI `Layout` protocol to implement `PanelFlowLayout`. The dashboard view reads `@Environment(\.horizontalSizeClass)` and passes the resolved fraction-per-slot table into the layout. The layout takes panels in order, asks each for its resolved fraction, and packs them into rows.

**Why:** Pre-grouping panels into row arrays via Swift code would require a separate pass and re-grouping every time something changes. A custom `Layout` lets SwiftUI do the work and react to size changes for free.

**Alternative considered:**
- *Pre-compute rows in Swift and render `ForEach` of `HStack` rows.* Simpler to read but causes the entire dashboard to re-layout when any panel re-renders. Acceptable fallback if `Layout` proves tricky for the rearrange/wiggle mode.

### D6: Edit/rearrange mode falls back to a single-column List

The existing edit mode uses a SwiftUI `List` so it can use the built-in `.onMove` for drag-to-reorder. That mode keeps panels one-per-row (single column) regardless of width — the user reorders by sort order, and width affects only the normal-mode display. This mirrors how the iOS Photos app shows a one-column list when editing albums even though display is grid.

**Why:** SwiftUI's `List` + `.onMove` is the only stable drag-and-drop API on iOS. Trying to support drag in a flow layout is a much bigger project and not worth the cost for a "make gauges share a row" feature.

## Risks / Trade-offs

- [Adaptive layout looks "broken" on the second device] → Mitigated by D1a: picker labels show the resolution explicitly, and a small "Adaptive layout · iPhone view" chip on the dashboard reveals what's happening when the user has at least one non-`full` panel.
- [Custom `Layout` is fiddly for height alignment] → Each panel has its own intrinsic height. The flow layout aligns panels within a row by their natural height; row height = max(panel heights). Visually verify with a row of one circular gauge (tall) + one single-value (short); if the whitespace is unacceptable, vertically center smaller panels in the row.
- [Compact styles look squashed at ¼ width on iPad portrait (≈180pt)] → ¼ width is the smallest the design produces. Visually verify each compact style at that size. If a particular style fails, restrict it via `allowedWidthSlots` to drop `small`.
- [User changes display style on a `small` panel to a chart] → On save, the edit view clamps `widthSlot` to a value supported by the new style (typically `full`) and shows a brief inline note.
- [Backup files from new builds are restored on old builds] → Old build ignores unknown attributes; restored panels fall back to `full` width and `lineBreakBefore` is dropped. Acceptable.
- [Lightweight Core Data migration could fail on a corrupt store] → New attributes are optional with no required default; migration is trivially lightweight.
- [Line breaks confuse users who didn't set them] → Default is false. The flag is only ever set by explicit user action via the "Break to new row" toggle. In rearrange mode the broken panel can show a small leading break-bar icon so the user can see why a row break exists.

## Migration Plan

1. Add a new model version that adds `widthSlot: String?` and `lineBreakBefore: Bool` (default false) to `DashboardPanel`. Lightweight migration is automatic.
2. Existing panels have `widthSlot = nil` (resolves to `full`) and `lineBreakBefore = false` — no behavior change on first launch.
3. New panels created via `AddPanelView` and `DemoSetup.swift` continue to leave both unset.
4. Ship.

**Rollback:** revert the model version. The new attributes are unread by older code so even saved data is harmless.

## Open Questions

- Should the width control live in the context menu or only inside the Edit Panel sheet? Recommendation: put it in both — a small `Width` submenu and a `Break to new row` toggle in the context menu, plus a section in `EditPanelView`.
- Where exactly does the "Adaptive layout · iPhone view" chip go — bottom of the scroll view, top of the dashboard, or as a navigation subtitle? Top-of-content seems most discoverable. Confirm during implementation.
- Should we visualize the line break in rearrange mode (e.g. a thin horizontal divider above the broken panel)? Recommended yes for v1, since rearrange is exactly when the user is thinking about layout structure.
