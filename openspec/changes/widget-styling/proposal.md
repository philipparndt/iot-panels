## Why

The in-app widget preview and the actual iOS home screen widget have visual differences — margins, padding, and background color don't match. The preview uses a fixed padding of 16 and a light tertiary background, while the real widget uses `.containerBackground` with system-managed insets. Users also want to choose a custom background color for their widgets, with a darker default that better suits IoT dashboards.

## What Changes

- Align padding/margins between `WidgetDesignPreviewView` (in-app preview) and `DesignWidgetView` (real home screen widget) so they match visually
- Add a configurable background color to `WidgetDesign` — stored as a hex string, with a darker default
- Expose background color picker in the widget editor
- Apply the chosen background in both the preview and the real widget's `.containerBackground`

## Capabilities

### New Capabilities
- `widget-background`: Configurable background color for widget designs with a darker default

### Modified Capabilities
- `widget-layout-parity`: Align padding and layout between preview and real widget rendering

## Impact

- **Core Data**: Add `backgroundColorHex` optional String attribute to `WidgetDesign` entity
- **WidgetDesign+Wrapped**: Add wrapper property with a darker default color
- **WidgetDesignEditorView**: Add background color picker section
- **WidgetDesignPreviewView**: Use the design's background color and match real widget padding
- **IoTPanelsWidget (DesignWidgetView)**: Use the design's background color in `.containerBackground`
- **Dependencies**: None
