## 1. Model

- [x] 1.1 Add `ThresholdRule` struct (`value: Double`, `colorHex: String`) conforming to `Codable, Equatable`
- [x] 1.2 Add `thresholds: [ThresholdRule]?` property to `StyleConfig`
- [x] 1.3 Add `resolvedColor(for value: Double, baseColor: Color) -> Color` method on `StyleConfig` that returns the threshold color or base color

## 2. PanelRenderer Integration

- [x] 2.1 Update `primaryColor` to use `styleConfig.resolvedColor(for:baseColor:)` with the latest data value
- [x] 2.2 Ensure single value text uses the resolved color
- [x] 2.3 Ensure single-series chart marks use the resolved color

## 3. Threshold Editor UI

- [x] 3.1 Create a reusable `ThresholdEditorView` that shows a list of threshold rules with value + color picker, and add/remove buttons
- [x] 3.2 Add `ThresholdEditorView` to `EditPanelView` (visible for all display styles except gauge)
- [x] 3.3 Add `ThresholdEditorView` to `WidgetItemConfigView` (same visibility)

## 4. Translations

- [x] 4.1 Add translations for threshold-related UI strings across all 8 languages

## 5. Testing

- [ ] 5.1 Verify threshold color changes when value crosses a breakpoint
- [ ] 5.2 Verify no thresholds = unchanged behavior
- [ ] 5.3 Verify thresholds persist and render correctly in widgets
