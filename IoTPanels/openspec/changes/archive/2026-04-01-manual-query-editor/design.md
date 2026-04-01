## Context

Queries are currently built from structured fields (measurement, fields, tags, time range, aggregation) in `QueryBuilderView`. The query string is generated at execution time by `SavedQuery+Wrapped.buildQuery(for:)`. Adding manual mode means storing and using a raw query string instead.

## Goals / Non-Goals

**Goals:**
- Allow writing raw Flux (InfluxDB 2), SQL (InfluxDB 3), or InfluxQL (InfluxDB 1) queries
- Show contextual syntax reference for the active backend type
- Support live preview (execute query and show results)
- Save raw queries alongside structured ones — both types coexist

**Non-Goals:**
- Syntax highlighting or code completion
- Query validation before execution
- Converting between manual and structured mode

## Decisions

### 1. Store raw query in SavedQuery

Add `rawQuery: String?` and `isRawQuery: Bool` to the Core Data model. When `isRawQuery` is true, `buildQuery(for:)` returns `rawQuery` directly. Structured fields are ignored but preserved (no data loss if user later creates a new structured query).

### 2. Syntax help as expandable reference sections

Show collapsible sections with common query patterns, functions, and examples for each backend type. This is more useful than a link to external docs because users can reference it inline while editing.

### 3. Editor as TextEditor with monospace font

Use SwiftUI `TextEditor` with a monospace font. Sufficient for query editing — no need for a custom syntax highlighting text view.

### 4. Entry point via query creation flow

When creating a new query, offer "Query Builder" (structured) and "Manual Query" (raw editor) as options. When editing, the mode is determined by `isRawQuery`.

## Risks / Trade-offs

- [Manual queries bypass aggregation/time range controls on panels] → Panel-level overrides (time range, aggregation) won't apply to raw queries. Document this in the help text.
- [Raw queries may return data in unexpected formats] → The chart parser already handles varied column layouts. If parsing fails, show "No data" gracefully.
