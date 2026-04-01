## 1. Color Palette

- [x] 1.1 Add adaptive primary color (#PRIMARY) to `SeriesColors.palette` — resolves to `.primary` (white in dark mode, black in light mode)

## 2. PanelRenderer Color Usage

- [x] 2.1 Extract a `primaryColor` computed property from `series.first?.color ?? .accentColor`
- [x] 2.2 Replace `.accentColor` with `primaryColor` in `singleSeriesPrimaryMarks` (line, area, bar, scatter, point)
- [x] 2.3 Replace `.accentColor` with `primaryColor` in single value body text
- [x] 2.4 Replace `Color.accentColor.complementary()` with `primaryColor.complementary()` in comparison marks
- [x] 2.5 Update area gradient to use `primaryColor` instead of `.accentColor`

## 3. Testing

- [ ] 3.1 Verify widget item color is applied to line chart
- [ ] 3.2 Verify widget item color is applied to single value text
- [ ] 3.3 Verify adaptive primary color renders white in dark mode, black in light mode
- [ ] 3.4 Verify dashboard charts are unaffected (still use accent color via series.color)
