## Context

IoT Panels already supports InfluxDB 2 (Flux), InfluxDB 3 (SQL), MQTT, and Demo. The architecture uses `DataSourceServiceProtocol` with `ServiceFactory` routing per `BackendType`. Adding InfluxDB 1.x follows the same pattern. The InfluxDB 3 implementation already established patterns for optional auth and database-based (vs bucket/org) configuration that InfluxDB 1.x can reuse.

## Goals / Non-Goals

**Goals:**
- Support InfluxDB 1.x as a first-class datasource
- Use the InfluxDB 1.x HTTP API (`/query` endpoint with InfluxQL)
- Support no auth and username/password auth
- Reuse existing Core Data attributes (`url`, `username`, `password`, `database`)
- Setup wizard with database auto-discovery

**Non-Goals:**
- Supporting InfluxDB 1.x continuous queries or retention policies management
- Supporting InfluxDB 1.x admin API
- Supporting HTTPS client certificates for InfluxDB 1.x

## Decisions

### 1. HTTP API via `/query` endpoint

InfluxDB 1.x exposes `GET /query?db=<db>&q=<influxql>` returning JSON with `results[].series[]` structure. This is well-documented and stable.

**Rationale**: Standard InfluxDB 1.x API. No external dependencies needed.

### 2. InfluxQL query generation

Add `buildInfluxQLQuery()` alongside existing Flux and SQL builders. InfluxQL uses `SELECT field FROM measurement WHERE time > now() - interval GROUP BY time(window)` syntax.

**Rationale**: InfluxQL is the native query language for InfluxDB 1.x. The structured query builder already captures measurement, fields, tags, time range, and aggregation — all map directly to InfluxQL.

### 3. Reuse `database` Core Data attribute

InfluxDB 1.x uses databases (same concept as InfluxDB 3). The `database` attribute added for InfluxDB 3 can be shared.

### 4. Auth via query parameters

InfluxDB 1.x accepts `u=<user>&p=<pass>` as query parameters or basic auth. Use query parameters for simplicity.

**Alternative considered**: Basic auth headers — works but query params are more common in InfluxDB 1.x deployments.

### 5. Database discovery via `SHOW DATABASES`

Use `GET /query?q=SHOW DATABASES` (no `db` parameter needed for this query).

## Risks / Trade-offs

- [InfluxDB 1.x JSON response format differs from InfluxDB 2/3] → Parse the `results[].series[].values` structure into `QueryResult`. Well-documented format.
- [Some InfluxDB 1.x deployments require HTTPS] → URL field already supports https:// prefixes.
