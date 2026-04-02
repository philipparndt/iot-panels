## Why

The demo data generator has several issues that prevent key features from being demonstrated:

1. **Comparison doesn't work**: Random base values are generated per query call. When the comparison query runs for yesterday's data, it gets completely different random values, making the comparison meaningless.
2. **Band charts don't work**: The demo service doesn't parse band query format (multiple `yield(name: "min/max/mean")` calls). It returns the same data for all three aggregates and doesn't suffix field names with `_min`, `_max`, `_mean`.
3. **No temporal consistency**: Data is fully random with no seed. The same time window produces different data on every query, so navigating away and back shows completely different charts.

## What Changes

- Use deterministic data generation seeded by timestamp — same time always produces the same value
- Support band queries: detect the `yield(name: "min")` / `yield(name: "max")` / `yield(name: "mean")` pattern and generate appropriate min/max/mean data with correct field name suffixes
- Support comparison queries: detect `range(start: -Xs, stop: -Ys)` format and generate data for the correct historical window
- Ensure temperature patterns are realistic: day/night cycles, consistent across queries

## Capabilities

### New Capabilities

### Modified Capabilities

## Impact

- **DemoService**: Rewrite data generation to be deterministic and support band/comparison queries
- **Dependencies**: None
