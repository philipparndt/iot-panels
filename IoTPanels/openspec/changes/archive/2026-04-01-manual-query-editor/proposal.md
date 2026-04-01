## Why

The structured query builder covers common cases but advanced users need to write custom queries — complex aggregations, subqueries, joins, or syntax not supported by the builder. A manual query editor with inline syntax help lets users harness the full power of each InfluxDB version's query language.

## What Changes

- **New `rawQuery` attribute** on `SavedQuery` Core Data entity to store a raw query string
- **New `isRawQuery` flag** on `SavedQuery` to indicate manual mode vs structured builder
- **Manual query editor view** with a multi-line text editor, syntax reference panel, and live preview
- **Query dispatch update** — when `isRawQuery` is true, use the raw query string directly instead of building from structured fields
- **Entry point** — add "Manual Query" option alongside the existing structured query builder when creating/editing queries

## Capabilities

### New Capabilities
- `manual-query-editor`: Raw query editing with syntax help for Flux, SQL, and InfluxQL

### Modified Capabilities

## Impact

- `SavedQuery` Core Data entity: Add `rawQuery` and `isRawQuery` attributes
- `SavedQuery+Wrapped.swift`: Add wrapped properties, update query dispatch
- New `ManualQueryEditorView.swift`: Editor with syntax help
- `SavedQueryListView` or query creation flow: Add entry point for manual queries
