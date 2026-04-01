## 1. Core Data & Model

- [x] 1.1 Add `backgroundColorHex` optional String attribute to `WidgetDesign` entity
- [x] 1.2 Add `wrappedBackgroundColor` property on `WidgetDesign` extension with dark default (#1C1C1E)

## 2. Background Color Picker

- [x] 2.1 Add background color picker section in `WidgetDesignEditorView` with preset colors (dark, black, charcoal, gray, light, white)
- [x] 2.2 Add translations for new UI strings across all 8 languages

## 3. Layout Parity

- [x] 3.1 Align padding between `WidgetDesignPreviewView` and `DesignWidgetView` so preview matches real widget
- [x] 3.2 Apply `wrappedBackgroundColor` in `WidgetDesignPreviewView` background
- [x] 3.3 Apply `wrappedBackgroundColor` in `DesignWidgetView` `.containerBackground`
- [x] 3.4 Pass background color through `WidgetDesignEntry` so real widget can use it

## 4. Testing

- [ ] 4.1 Verify preview matches real widget layout at all three sizes (2×2, 4×2, 4×4)
- [ ] 4.2 Verify background color persists and renders correctly on home screen
- [ ] 4.3 Verify default dark background on new widget designs
