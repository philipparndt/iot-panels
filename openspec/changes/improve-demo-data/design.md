## Context

`DemoService` implements `DataSourceServiceProtocol` and generates fake data by parsing Flux queries. It extracts measurement, fields, range, and window from the query string. The data generators use `Double.random()` and per-call random base values, making output non-deterministic.

## Goals / Non-Goals

**Goals:**
- Deterministic data: same timestamp → same value (seeded by time)
- Band query support: detect yield names, generate min < mean < max with correct `_min`/`_max`/`_mean` suffixed fields
- Comparison query support: detect `range(start: -Xs, stop: -Ys)` format for historical windows
- Realistic patterns: consistent day/night temperature cycles, smooth curves

**Non-Goals:**
- Simulating network delays or errors
- Changing the demo home setup (DemoSetup.swift)

## Decisions

### 1. Deterministic random using time-based seed

Replace `Double.random()` with a deterministic function seeded by the data point's timestamp. Use a simple hash of the timestamp to generate consistent "random" variation:

```swift
func noise(for date: Date, seed: Int) -> Double {
    let hash = Int(date.timeIntervalSince1970 * 1000) &+ seed
    return Double((hash &* 2654435761) % 1000) / 1000.0  // 0.0 to 1.0
}
```

Same timestamp + seed always produces the same noise value.

### 2. Band query detection

Parse `yield(name: "min")`, `yield(name: "max")`, `yield(name: "mean")` from the query. When detected:
- Generate base mean values using the normal generator
- `_mean` = base value
- `_min` = base - spread (e.g., 1-3°C below mean)
- `_max` = base + spread (e.g., 1-3°C above mean)
- Suffix field names accordingly

### 3. Comparison query detection

Parse `range(start: -Xs, stop: -Ys)` format (seconds-based range with explicit stop). The existing parser only handles `range(start: -2h)` format. Add support for the seconds-based format used by comparison and explorer offset queries.

### 4. Stable base values per measurement

Instead of `Double.random(in: 18...24)` for the temperature base, derive it from the measurement name hash. E.g., "living_room" always gets base 21.5°C.
