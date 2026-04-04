## Context

The app currently formats values with `formatValue(_ value: Double) -> String` which does simple rounding (0 or 1 decimal places) and appends the unit string as-is. The unit is a free-text string stored on `SavedQuery.unit` (e.g., "B", "W", "%", "°C"). The same `formatValue` function is duplicated in `PanelCardView.swift`, `SingleValueWidget.swift`, and `IoTPanelsWatchWidget.swift`.

## Goals / Non-Goals

**Goals:**
- Auto-scale values into the most readable magnitude for their unit family
- Support common IoT/infrastructure unit families (bytes, watts, time, volts, amps, etc.)
- Consolidate the duplicated `formatValue` into a shared utility
- Preserve existing behavior for units not in a known family (e.g., "°C", "ppm")

**Non-Goals:**
- Cross-unit-family conversion (e.g., °C → °F) — this is a different feature
- User-configurable scaling preferences — always auto-scale
- Changing how units are stored — the base unit string stays as-is in Core Data

## Decisions

### 1. Unit family lookup by base unit string

`UnitFormatter` defines a table of unit families. Each family is an ordered list of `(threshold, suffix)` pairs. When formatting, the formatter looks up the stored unit string in the family table, finds which scale the unit is at, converts the value to the base of that family, then picks the best display scale.

Example for bytes family:
```
B  → base (×1)
KB → ×1024
MB → ×1024²
GB → ×1024³
TB → ×1024⁴
```

If the stored unit is "B" and value is `5307109376`, the formatter computes: 5307109376 / 1024³ = 4.94 → display as "4.94 GB".

**Why a lookup table over Foundation's `Measurement`/`Unit`**: Foundation's unit system doesn't cover all our units (e.g., no bytes with 1024 base, no IoT-specific units). A simple lookup table is more predictable and has zero overhead.

### 2. Binary (1024) for bytes, SI (1000) for everything else

Bytes use 1024-based scaling (KiB convention, but displayed as KB/MB/GB for familiarity). All other units use 1000-based SI prefixes.

**Why**: This matches what users expect from monitoring tools like Grafana and Prometheus.

### 3. Shared `UnitFormatter.format(value:unit:)` replaces `formatValue`

A single static method `UnitFormatter.format(value: Double, unit: String) -> (value: String, unit: String)` returns the formatted value string and the scaled unit string separately. This keeps the existing layout pattern where value and unit are styled independently.

### 4. Smart decimal places based on magnitude

- Values ≥ 100: 0 decimal places (e.g., "512 MB")
- Values ≥ 10: 1 decimal place (e.g., "49.3 GB")
- Values ≥ 1: 2 decimal places (e.g., "4.94 GB")
- Values < 1: 2 decimal places (e.g., "0.23 TB")

## Risks / Trade-offs

- **Unexpected scaling for ambiguous units** → If a user enters "m" meaning "meters" but also has "m" in a different context, it'll still scale to km/mm. Mitigation: only scale units that are in the explicit family table; unknown units pass through unchanged.

- **Rate units like "B/s"** → The formatter needs to handle compound units like "B/s" by scaling only the prefix part. The "/s" suffix is preserved.
