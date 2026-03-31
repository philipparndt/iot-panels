## 1. Complementary Color Utility

- [x] 1.1 Add a `complementary()` method to `Color` in `ColorUtilities.swift` that rotates hue by 180° in HSB color space

## 2. Comparison Series Color Assignment

- [x] 2.1 In `PanelCardView.swift`, update comparison series color assignment to use `complementary()` instead of `.opacity(0.3)` on the same color
- [x] 2.2 Update comparison legend/indicator styling to match the new complementary color

## 3. Band Chart Comparison Rendering

- [x] 3.1 In `PanelCardView.swift`, skip `AreaMark` rendering for comparison band groups (keep only the mean `LineMark`)
- [x] 3.2 Verify primary band rendering remains unchanged when comparison is active
