## 1. Model Changes

- [x] 1.1 Add `gridColumns` computed property to `WidgetSizeType` (small=1, medium=dynamic based on count, large=2)
- [x] 1.2 Update `maxCells` for large from 4 to 6

## 2. Shared Grid Layout

- [x] 2.1 Create a grid layout helper (VStack of HStacks) that takes groups, column count, and renders cells in a wrapping grid
- [x] 2.2 Handle odd item counts — last row's single item takes full width
- [x] 2.3 Set compact mode based on grid density (compact when 2+ columns or 2+ rows)

## 3. Apply Grid Layout

- [x] 3.1 Replace HStack/VStack layout in `WidgetCanvas` with the shared grid
- [x] 3.2 Replace HStack/VStack layout in `WidgetCanvasFromEntry` with the shared grid

## 4. Testing

- [ ] 4.1 Verify small widget renders 1 item filling the space
- [ ] 4.2 Verify medium widget renders 1-3 items in a row
- [ ] 4.3 Verify large widget renders 2×2 grid for 4 items
- [ ] 4.4 Verify large widget renders 2+1 layout for 3 items (last item full width)
- [ ] 4.5 Verify preview and real widget layouts match
