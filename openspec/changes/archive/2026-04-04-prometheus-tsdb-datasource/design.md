## Context

IoT Panels currently supports five backend types: InfluxDB 1/2/3, MQTT, and Demo. Each backend implements `DataSourceServiceProtocol` and is instantiated via `ServiceFactory`. The app uses Core Data with CloudKit sync for persistence, and the `DataSource` entity already has generic fields (`url`, `token`, `username`, `password`, `ssl`, `untrustedSSL`) that can be reused for Prometheus.

Prometheus exposes a well-documented HTTP API for querying time-series data. The query language is PromQL. The API returns JSON with result types: matrix (range vectors), vector (instant vectors), and scalar.

## Goals / Non-Goals

**Goals:**
- Add Prometheus as a first-class datasource with the same UX quality as InfluxDB
- Support the Prometheus HTTP Query API (`/api/v1/query`, `/api/v1/query_range`)
- Support metric discovery and label-based filtering via the metadata API
- Support authentication (none, basic auth, bearer token) and TLS
- Map Prometheus results to the existing `QueryResult` format so dashboards and widgets work without modification
- Provide a guided setup wizard consistent with existing InfluxDB setup flows

**Non-Goals:**
- Remote write / push support — Prometheus is pull-based, we only read
- Alertmanager integration
- Recording rules management
- Support for Thanos, Cortex, or Mimir-specific APIs (though these are largely Prometheus-compatible and may work out of the box)
- Federation query support

## Decisions

### 1. Reuse existing Core Data fields — no schema migration

The `DataSource` entity already has `url`, `token`, `username`, `password`, `ssl`, and `untrustedSSL` attributes. For Prometheus:
- `url` → Prometheus server URL (e.g., `http://prometheus:9090`)
- `token` → Bearer token (when using bearer auth)
- `username` / `password` → Basic auth credentials
- `ssl` / `untrustedSSL` → TLS settings

**Why over adding new fields**: Avoids a Core Data migration, keeps CloudKit sync stable, and follows the same pattern used by InfluxDB backends.

### 2. Pure URLSession — no external dependencies

Prometheus HTTP API is a straightforward REST/JSON API. All requests use `GET` or `POST` with URL-encoded parameters. Responses are JSON.

**Why over a Prometheus client library**: No suitable Swift library exists with the quality bar we'd want. URLSession is already used for all InfluxDB services. Zero dependency increase.

### 3. Map PromQL results to QueryResult with time as a column

Prometheus returns matrix results as `{ metric: {labels}, values: [[timestamp, value], ...] }`. We'll map this to `QueryResult` with:
- A `time` column (ISO 8601 formatted)
- A `value` column
- One column per label key

For multi-series results (e.g., `cpu_usage{host=~".*"}`), each series maps to a set of rows. The label columns allow the existing chart renderer to group by labels, similar to how InfluxDB tag columns work.

**Why this mapping**: The existing `PanelCardView` chart rendering already handles time + value + grouping columns. By producing the same shape, Prometheus data renders without any chart code changes.

### 4. Step-based setup wizard following InfluxDB3 pattern

The setup flow will follow the same step-based pattern as `InfluxDB3SetupView`:
1. **Connect** — Enter server URL, choose auth method, test connection
2. **Finish** — Connection confirmed, save datasource

No database selection step needed (unlike InfluxDB) since Prometheus doesn't have that concept.

**Why over a single-form approach**: Consistency with existing UX. The step-based wizard validates the connection before saving, preventing misconfigured datasources.

### 5. Query builder with metric picker + label filters + raw PromQL

The query builder will have two modes:
- **Guided mode**: Metric selector (fetched via `/api/v1/label/__name__/values`), label filter builder (fetched via `/api/v1/labels` and `/api/v1/label/<name>/values`), and aggregate function selector
- **Raw PromQL mode**: Free-text editor for advanced queries (reusing the existing `isRawQuery` / `rawQuery` SavedQuery fields)

The guided mode generates PromQL from the selections. Measurements map to metric names, tags map to labels.

**Why both modes**: Guided mode lowers the barrier for simple queries. Raw PromQL mode is essential for Prometheus power users who need functions like `rate()`, `histogram_quantile()`, or complex joins.

### 6. Time range mapping to PromQL duration syntax

The app's existing `TimeRange` model uses durations like "1h", "24h", "7d". Prometheus `query_range` expects explicit `start`/`end` timestamps and a `step` parameter. We'll:
- Convert `TimeRange` to absolute `start`/`end` Unix timestamps
- Auto-calculate `step` based on the range (e.g., 1h → 15s step, 24h → 1m step, 7d → 5m step) to keep result density reasonable

## Risks / Trade-offs

- **Large metric cardinality** → Metric/label discovery APIs can be slow on Prometheus instances with millions of series. Mitigation: paginate metric lists, add search filtering in the picker UI, use `match[]` parameter to scope label queries.

- **PromQL complexity not fully expressible in guided mode** → Functions like `rate()`, `histogram_quantile()`, subqueries, and binary operators can't be composed visually. Mitigation: Raw PromQL mode as escape hatch. The guided mode covers the 80% case (select metric, filter by labels, apply basic aggregation).

- **No schema concept in Prometheus** → Unlike InfluxDB's measurements/fields/tags hierarchy, Prometheus has a flat metric namespace with labels. The `DataSourceServiceProtocol` methods (`fetchMeasurements`, `fetchFieldKeys`, `fetchTagKeys`) map imperfectly. Mitigation: `fetchMeasurements` returns metric names, `fetchFieldKeys` returns `["value"]` (Prometheus metrics are single-valued), `fetchTagKeys` returns label names for a given metric.

- **Step parameter affects data granularity** → Too large a step loses detail; too small a step returns excessive data. Mitigation: Auto-calculate based on time range with sensible defaults, matching the aggregate window concept used for InfluxDB.
