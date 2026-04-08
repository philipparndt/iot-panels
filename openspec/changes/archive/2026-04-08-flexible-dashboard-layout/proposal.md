## Why

Today every panel on a dashboard occupies a full row inside the `LazyVStack` in `DashboardView.swift`. Two problems follow:

1. On iPhone, compact styles (circular gauges, single-value cards, status indicators) waste vertical space — the user scrolls through a long, mostly-empty column instead of seeing a compact summary at a glance.
2. On iPad, *every* panel — including charts — gets stretched across the full screen width, which is ungainly and gives no benefit from the larger screen. The dashboard looks the same on iPad as it does on iPhone, just bigger.

A single mechanism can fix both: let the user pick a *size hint* per panel that resolves to "more columns per row" on larger screens automatically.

## What Changes

- Add a per-panel **width slot** attribute on `DashboardPanel` with three values: `small`, `medium`, `full`.
- Resolve the slot to a column span at render time based on the dashboard's horizontal size class:
  - `small` → ½ width on compact (iPhone), ¼ width on regular (iPad)
  - `medium` → full width on compact, ½ width on regular
  - `full` → full width on every screen
- Replace the dashboard's `LazyVStack` with a flow layout that packs panels into rows by sort order, starting a new row whenever the next panel would overflow the available row capacity.
- Add a width control and a "Break to new row" toggle to the panel's context menu and to `EditPanelView`. The break flag (`lineBreakBefore`) lets the user force a row to end before a panel even if more would fit, for visual grouping.
- Make the adaptive behavior visible: width picker labels show what each slot resolves to on the current screen size, and an "Adaptive layout · iPhone view / iPad view" chip appears on the dashboard whenever any panel uses a non-`full` slot, so the user understands a different arrangement on another device is intentional, not a bug.
- Default newly-created panels to `full` so existing dashboards look identical after upgrade.
- Restrict `small` and `medium` to display styles that remain legible at narrower widths (gauges, single value, sparkline, status indicator); chart-type styles are pinned to `full`. Changing a `small` panel's display style to a chart automatically clamps it back to `full`.
- Ensure rearrange / drag-to-reorder mode still works. Sort order remains authoritative; width slot only affects which panels share a row in normal mode.

## Capabilities

### New Capabilities
- `dashboard-flow-layout`: Per-panel width on the dashboard, multi-panel rows, the editing affordance to change width, and the rendering rules that pack panels into rows by sort order.

### Modified Capabilities
None — the dashboard view didn't previously have a spec for layout, so this is purely additive.

## Impact

- Code: `IoTPanels/IoTPanels/Views/Dashboard/DashboardView.swift` (layout rewrite for normal mode), `IoTPanels/IoTPanels/Views/Dashboard/PanelCardView.swift` (must render correctly down to ¼ width on iPad), `EditPanelView` (width picker).
- Data model: `DashboardPanel` gains an optional `widthSlot: String` attribute and a `lineBreakBefore: Bool` attribute (default false). Bumps the model version. Lightweight migration; absent values resolve to `full` and `false`.
- Backup/restore: the new attribute is part of the panel JSON shape and must round-trip.
- Risk: a circular gauge at ¼ width on iPad portrait (~180pt) is the smallest size we ship. Need to visually verify all compact styles at that size.
