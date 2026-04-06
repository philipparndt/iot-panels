## Context

The display style picker currently shows all chart types in a flat list — a `ForEach` over `PanelDisplayStyle.allCases` with icon + name. With 12 types today and more planned, users need to scan the entire list to find what they want. Grouping by category reduces cognitive load.

## Goals / Non-Goals

**Goals:**
- Group chart types into intuitive categories in both dashboard panel and widget item pickers
- Make the picker more visual with small preview illustrations
- Keep the selection experience fast — no extra navigation steps

**Non-Goals:**
- Changing chart type behavior or rendering
- Adding new chart types (handled by separate changes)
- Search/filter functionality (not needed at <20 types)

## Decisions

### 1. Category as a computed property on PanelDisplayStyle

**Decision:** Add a `category: ChartCategory` computed property to `PanelDisplayStyle` and a `ChartCategory` enum with cases: `timeSeries`, `stateStatus`, `values`, `grid`, `other`.

**Rationale:** Keeps categorization co-located with the style definition. A computed property means no stored data changes. The category enum provides `displayName` and ordering.

**Alternatives considered:**
- External mapping dictionary: separates categorization from the type, harder to keep in sync
- Nested enum: would break `CaseIterable` and existing code that iterates styles

### 2. Sectioned list, not grid

**Decision:** Use SwiftUI `Section` headers within the existing list/menu picker rather than a grid layout with thumbnails.

**Rationale:** Sectioned list is the minimal change — wrap existing `ForEach` in grouped sections. A visual grid with mini chart previews would be ideal long-term but requires rendering or maintaining static preview images for each type. The sectioned list scales well to ~20 types and can be evolved to a grid later.

**Layout:**
```
┌────────────────────────────┐
│ TIME SERIES                │
│  📈 Line               ✓  │
│  📊 Bar                   │
│  ⦿  Scatter               │
│  📈 Line + Points         │
│  ≋  Band                  │
│                            │
│ VALUES                     │
│  42 Value                  │
│  ▰▰ Gauge                 │
│  ◔  Circular Gauge        │
│                            │
│ GRID                       │
│  📅 Calendar               │
│  📅 Calendar Dense         │
│                            │
│ OTHER                      │
│  ⊘  Auto                  │
│  Aa Text                   │
└────────────────────────────┘
```

### 3. Auto goes in "Other", not at top

**Decision:** Place "Auto" in the "Other" section rather than giving it a special position at the top.

**Rationale:** Auto is a convenience default, not a chart category. Keeping it in a section maintains the grouping pattern. It's already the default selection for new items, so users rarely need to find it in the picker.

## Risks / Trade-offs

- **[Category drift]** → As new chart types are added, categories may need rethinking. Mitigation: categories are a simple computed property, easy to change.
- **[Picker height]** → Section headers add vertical space, making the picker taller. Mitigation: section headers are compact single-line text; the total height increase is minimal.
