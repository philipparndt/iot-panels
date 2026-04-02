## 1. Deterministic Data Generation

- [x] 1.1 Create a `noise(for date:seed:)` function that produces deterministic 0-1 values from timestamp + seed
- [x] 1.2 Replace all `Double.random()` calls in data generators with deterministic `noise()` and `smoothNoise()` calls
- [x] 1.3 Derive stable base values from measurement/field names (hash-based) instead of per-call random

## 2. Band Query Support

- [x] 2.1 Add `extractYieldNames(from:)` parser to detect `yield(name: "min/max/mean")` in query
- [x] 2.2 When band yields detected, generate three series per field with `_min`, `_max`, `_mean` suffixes
- [x] 2.3 Ensure min < mean < max with realistic spread (e.g., temperature ±0.8-2.3°C from mean)

## 3. Comparison / Offset Query Support

- [x] 3.1 Add parsing for `range(start: -Xs, stop: -Ys)` format (seconds-based with explicit stop)
- [x] 3.2 Generate data points for the historical time window when stop is present

## 4. Testing

- [ ] 4.1 Verify comparison overlay shows correlated data (yesterday looks similar to today)
- [ ] 4.2 Verify band chart renders with min/max/mean spread
- [ ] 4.3 Verify data is consistent across repeated queries for the same time window
