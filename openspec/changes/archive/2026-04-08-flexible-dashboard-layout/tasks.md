## 1. Data model

- [x] 1.1 Add a new Core Data model version (`IoTPanels N+1.xcdatamodel`) and set it as the current version  *(in-place edit per project pattern; no version bundle exists)*
- [x] 1.2 Add an optional `widthSlot: String` attribute to `DashboardPanel` in the new model version
- [x] 1.3 Add a `lineBreakBefore: Bool` attribute (default `NO`) to `DashboardPanel` in the new model version
- [ ] 1.4 Verify lightweight migration succeeds from the previous version on a snapshot store  *(manual — both new attributes are optional / scalar with default, so lightweight migration is automatic)*

## 2. Domain types

- [x] 2.1 Add a `PanelWidthSlot` Swift enum with cases `.small`, `.medium`, `.full` and `rawValue` matching the stored strings
- [x] 2.2 Add `DashboardPanel.wrappedWidthSlot: PanelWidthSlot` (get/set) that maps `nil` → `.full`
- [x] 2.3 Add a `PanelWidthSlot.fraction(for sizeClass: UserInterfaceSizeClass?) -> Double` resolving small/medium/full to (0.5, 1.0, 1.0) on compact and (0.25, 0.5, 1.0) on regular
- [x] 2.4 Add `PanelDisplayStyle.allowedWidthSlots -> [PanelWidthSlot]` returning `[.full]` for chart styles and `[.small, .medium, .full]` for compact styles (circular gauge, linear gauge, single value, sparkline, status indicator, state indicator)
- [x] 2.5 Add `DashboardPanel.lineBreakBefore` Bool wrapper (Core Data already exposes it; ensure default is false)

## 3. Layout

- [x] 3.1 Implement a `PanelFlowLayout` SwiftUI `Layout` that takes per-child fractions, places children in left-to-right rows, packs by accumulated fraction, and respects forced line breaks
- [x] 3.2 Replace the `LazyVStack` panel loop in `DashboardView.normalContent` with `PanelFlowLayout`, reading `@Environment(\.horizontalSizeClass)` to resolve each panel's slot to a fraction
- [x] 3.3 Pass each panel's `lineBreakBefore` into the layout via a layout-value modifier so the layout can detect break markers
- [ ] 3.4 Verify that `PanelCardView` renders correctly down to ¼ width on iPad (≈180pt) for each compact display style — adjust internal padding/font sizes only if necessary  *(manual)*
- [ ] 3.5 Verify row alignment when a row mixes panels of different intrinsic heights  *(manual)*

## 4. Adaptive-layout visibility

- [x] 4.1 Build the width picker (used by both context menu and edit sheet) so each option's label includes the resolution mapping (e.g. "Small — 2 per row on iPhone, 4 per row on iPad")
- [x] 4.2 Add an "Adaptive layout · iPhone view / iPad view" chip to `DashboardView`, shown only when at least one panel on the current dashboard has a non-`full` slot
- [x] 4.3 Tapping the chip presents a popover that shows the slot-to-fraction mapping for the current size class and the alternative size class

## 5. Edit affordance

- [x] 5.1 Add a Width submenu to the panel's context menu in `DashboardView.normalContent`, listing only the slots returned by `panel.wrappedDisplayStyle.allowedWidthSlots`, with a checkmark on the current slot
- [x] 5.2 Add a "Break to new row" toggle to the panel's context menu (always available)
- [x] 5.3 Add a Width section and a "Break to new row" toggle to `EditPanelView`'s form
- [x] 5.4 In `EditPanelView`'s save path, clamp `widthSlot` to a value allowed by the (possibly newly-changed) display style
- [x] 5.5 Make sure changing slot or break triggers a dashboard re-render (mark `dashboard.modifiedAt`, save, bump `refreshID`)

## 6. Rearrange mode

- [x] 6.1 Confirm `DashboardView.editModeContent` continues to render panels one-per-row in the rearrange `List` regardless of `widthSlot`
- [x] 6.2 Show a visual marker (thin divider or break-bar icon) above any panel with `lineBreakBefore = true` in rearrange mode
- [x] 6.3 Confirm `.onMove` still updates `sortOrder` correctly and that returning to normal mode reflects the new order in the flow layout, with break markers preserved

## 7. Backup / restore

- [x] 7.1 Include `widthSlot` and `lineBreakBefore` in the panel's JSON encoding in `BackupService.swift`
- [x] 7.2 Decode both on restore; absence falls back to nil/false
- [ ] 7.3 Round-trip test: export a dashboard with mixed slots and a forced break, import it, verify all values preserved  *(manual)*

## 8. Localization

- [ ] 8.1 Add localized strings for "Width", "Small", "Medium", "Full width", "Break to new row", "Adaptive layout", "iPhone view", "iPad view", and the picker resolution descriptions in `Localizable.xcstrings` for all supported languages  *(deferred — Xcode auto-extracts new `String(localized:)` and `Text` literals on build; ask to fill translations after first build, same flow used for "New Demo Home")*

## 9. Verification

- [ ] 9.1 Manual test on iPhone: row of two `small` circular gauges, row of three `small` single-value cards (NB: only two-up on iPhone — third panel wraps), forced break between two pairs of gauges
- [ ] 9.2 Manual test on iPad portrait: same dashboard as 9.1 — verify the small panels reflow to four-per-row, that the chip appears, and that picker labels show both resolutions
- [ ] 9.3 Manual test on iPad landscape: rotate the same dashboard — verify reflow without reorder
- [ ] 9.4 Tap the "Adaptive layout" chip and verify the popover explains the mapping
- [ ] 9.5 Confirm pre-existing dashboards (created before the change) render unchanged after upgrade and the chip is hidden
- [ ] 9.6 Confirm iCloud-synced slot and break changes propagate to a second device
- [ ] 9.7 Change a `small` gauge panel's display style to a line chart in the edit sheet and verify the slot is clamped to `full` on save
