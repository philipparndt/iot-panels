## Context

The preview (`WidgetDesignPreviewView`) wraps content in a `GeometryReader` with `.padding(16)` and a `Color(uiColor: .tertiarySystemBackground)` background. The real widget (`DesignWidgetView`) uses `.containerBackground(for: .widget) { ContainerRelativeShape().fill(.tertiary) }` which has system-managed insets that differ from the fixed 16pt padding. This causes charts to appear at different sizes in preview vs home screen.

## Goals / Non-Goals

**Goals:**
- Match preview padding to real widget padding so WYSIWYG
- Add a background color property to `WidgetDesign` with a darker default (e.g., dark gray `#1C1C1E`)
- Provide a color picker in the widget editor for background selection
- Apply the same background in preview and real widget

**Non-Goals:**
- Background images or gradients (keep it simple — solid color)
- Per-item background colors (background is per-widget-design)

## Decisions

### 1. Store background as hex string on WidgetDesign

Add `backgroundColorHex` optional String attribute. Default to a dark color (`#1C1C1E`) when nil. This matches the iOS dark mode system background and looks better for IoT data dashboards.

### 2. Match padding via shared constant

Extract the widget content padding into a shared value used by both preview and real widget. The real widget's `.containerBackground` adds its own safe area insets — the preview should simulate this by using the same padding value.

### 3. Provide preset color palette + custom picker

Offer a row of preset background colors (dark, black, system, light) plus the ability to pick any color. Keep it simple.

## Risks / Trade-offs

- **[Light mode readability]** A dark default background may clash with light mode chart text → Mitigated by PanelRenderer already adapting to colorScheme; the background color choice is the user's responsibility.
- **[Lightweight migration]** Adding one optional String attribute to WidgetDesign → Automatic lightweight migration, no risk.
