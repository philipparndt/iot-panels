## Context

`PanelRenderer.singleValueBody` uses `VStack(alignment: .leading)` for both dashboard and widget rendering. In widgets, the single value fills the whole cell and centering looks more balanced.

## Goals / Non-Goals

**Goals:**
- Center single value text in compact/widget context
- Keep left-aligned for dashboard cards

**Non-Goals:**
- Changing multi-value layout
- Adding alignment as a user setting

## Decisions

### 1. Use compact flag to determine alignment

When `compact` is true (widgets), use `VStack(alignment: .center)` and center the frame. When false (dashboards), keep `VStack(alignment: .leading)`.
