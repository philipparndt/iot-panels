## Why

Values like `5307109376 B` or `0.000234 A` are hard to read. When a Prometheus query returns bytes, the user has to mentally convert to GB. The same problem applies to other units — watts displayed as milliwatts, seconds as days, etc. Automated unit scaling makes dashboards immediately readable without manual calculation.

## What Changes

- **Auto-scaling value formatter**: A new `UnitFormatter` utility that automatically scales numeric values to the most human-readable unit prefix within the same unit family (e.g., `5307109376 B` → `4.94 GB`, `0.023 A` → `23.0 mA`, `86472 s` → `1.0 days`).
- **Integration into all display paths**: Replace the current `formatValue()` + unitSuffix pattern with a unit-aware formatter in PanelCardView, SingleValueWidget, and IoTPanelsWatchWidget.
- **Unit family definitions**: Define conversion scales for common unit families — bytes (B/KB/MB/GB/TB), watts (mW/W/kW/MW), time (ms/s/min/h/d), volts (µV/mV/V/kV), amps (µA/mA/A), speed (m/s/km/h), distance (mm/cm/m/km), and generic SI prefixes.

## Capabilities

### New Capabilities
- `auto-unit-scaling`: Automatic value scaling and unit prefix selection based on configured base unit

### Modified Capabilities

## Impact

- **New file**: `Model/UnitFormatter.swift` containing the scaling logic
- **PanelCardView.swift**: Update `formatValue()` calls to use `UnitFormatter`
- **SingleValueWidget.swift**: Same update for widget display
- **IoTPanelsWatchWidget.swift**: Same update for watch widget display
- **No Core Data changes**: The stored unit string is the base unit; scaling is a display-only concern
- **Backward compatible**: Values with units not in a known family display as before (no scaling)
