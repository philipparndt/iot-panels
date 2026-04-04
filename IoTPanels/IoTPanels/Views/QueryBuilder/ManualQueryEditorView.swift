import SwiftUI

struct ManualQueryEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let dataSource: DataSource
    let existingQuery: SavedQuery?

    @State private var queryName = ""
    @State private var queryText = ""
    @State private var selectedUnit = ""
    @State private var customUnit = ""
    @State private var showingPreview = false
    @State private var showingHelp = false

    private var effectiveUnit: String { customUnit.isEmpty ? selectedUnit : customUnit }
    private var canSave: Bool { !queryName.isEmpty && !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var backendType: BackendType { dataSource.wrappedBackendType }
    private var service: any DataSourceServiceProtocol { ServiceFactory.service(for: dataSource) }

    private var languageName: String {
        switch backendType {
        case .influxDB1: return "InfluxQL"
        case .influxDB2: return "Flux"
        case .influxDB3: return "SQL"
        case .prometheus: return "PromQL"
        default: return "Query"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Query name", text: $queryName)
                }

                Section {
                    TextEditor(text: $queryText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    HStack {
                        Text(languageName)
                        Spacer()
                        Button {
                            showingHelp.toggle()
                        } label: {
                            Label("Help", systemImage: "questionmark.circle")
                                .font(.caption)
                        }
                    }
                } footer: {
                    if queryText.isEmpty {
                        Text(placeholderText)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if showingHelp {
                    syntaxReference
                }

                // Unit
                Section {
                    NavigationLink {
                        UnitPickerPage(
                            selectedUnit: $selectedUnit,
                            customUnit: $customUnit
                        )
                    } label: {
                        HStack {
                            Text("Unit")
                            Spacer()
                            if !effectiveUnit.isEmpty {
                                Text(effectiveUnit)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Preview
                Section {
                    NavigationLink {
                        QueryPreviewPage(flux: queryText, service: service)
                    } label: {
                        Label("Preview Query", systemImage: "play.circle")
                    }
                    .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(existingQuery != nil ? "Edit Query" : "Manual Query")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveQuery)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    // MARK: - Placeholder

    private var placeholderText: String {
        switch backendType {
        case .influxDB1:
            return "SELECT \"value\" FROM \"measurement\" WHERE time > now() - 2h"
        case .influxDB2:
            return "from(bucket: \"my-bucket\") |> range(start: -2h) |> filter(...)"
        case .influxDB3:
            return "SELECT * FROM \"measurement\" WHERE time >= NOW() - INTERVAL '2 hours'"
        case .prometheus:
            return "rate(http_requests_total{job=\"api\"}[5m])"
        default:
            return ""
        }
    }

    // MARK: - Syntax Reference

    @ViewBuilder
    private var syntaxReference: some View {
        switch backendType {
        case .influxDB1:
            influxQLReference
        case .influxDB2:
            fluxReference
        case .influxDB3:
            sqlReference
        case .prometheus:
            promqlReference
        default:
            EmptyView()
        }
    }

    private var influxQLReference: some View {
        Section("InfluxQL Reference") {
            referenceGroup("Basic Query", [
                "SELECT \"field\" FROM \"measurement\"",
                "  WHERE time > now() - 2h",
                "SELECT * FROM \"cpu\" LIMIT 10"
            ])
            referenceGroup("Aggregation", [
                "SELECT MEAN(\"value\") FROM \"temp\"",
                "  WHERE time > now() - 1d",
                "  GROUP BY time(5m) fill(none)"
            ])
            referenceGroup("Filters", [
                "WHERE \"host\" = 'server01'",
                "  AND \"region\" = 'us-east'",
                "WHERE time > now() - 7d"
            ])
            referenceGroup("Functions", [
                "MEAN, MEDIAN, SUM, COUNT",
                "MIN, MAX, FIRST, LAST",
                "DERIVATIVE, DIFFERENCE",
                "MOVING_AVERAGE, CUMULATIVE_SUM"
            ])
            referenceGroup("Multiple Fields", [
                "SELECT MEAN(\"temp\"), MEAN(\"hum\")",
                "  FROM \"sensors\"",
                "  GROUP BY time(10m)"
            ])
        }
    }

    private var fluxReference: some View {
        Section("Flux Reference") {
            referenceGroup("Basic Query", [
                "from(bucket: \"my-bucket\")",
                "  |> range(start: -2h)",
                "  |> filter(fn: (r) =>",
                "    r._measurement == \"temp\")",
                "  |> yield()"
            ])
            referenceGroup("Aggregation", [
                "|> aggregateWindow(",
                "    every: 5m,",
                "    fn: mean,",
                "    createEmpty: false)"
            ])
            referenceGroup("Filters", [
                "|> filter(fn: (r) =>",
                "    r._field == \"value\")",
                "|> filter(fn: (r) =>",
                "    r.host == \"server01\")"
            ])
            referenceGroup("Functions", [
                "mean, median, sum, count",
                "min, max, first, last",
                "derivative, difference",
                "movingAverage, cumulativeSum"
            ])
            referenceGroup("Multiple Fields", [
                "|> filter(fn: (r) =>",
                "    r._field == \"temp\" or",
                "    r._field == \"humidity\")"
            ])
        }
    }

    private var sqlReference: some View {
        Section("SQL Reference (InfluxDB 3)") {
            referenceGroup("Basic Query", [
                "SELECT time, value",
                "  FROM \"measurement\"",
                "  WHERE time >= NOW() - INTERVAL '2 hours'",
                "  ORDER BY time"
            ])
            referenceGroup("Aggregation", [
                "SELECT",
                "  DATE_BIN(INTERVAL '5 min', time) AS time,",
                "  AVG(value) AS value",
                "FROM \"measurement\"",
                "  WHERE time >= NOW() - INTERVAL '1 day'",
                "  GROUP BY 1 ORDER BY 1"
            ])
            referenceGroup("Filters", [
                "WHERE \"location\" IN ('kitchen', 'bath')",
                "  AND time >= NOW() - INTERVAL '7 days'",
                "WHERE value > 20.0"
            ])
            referenceGroup("Functions", [
                "AVG, SUM, COUNT, MIN, MAX",
                "FIRST_VALUE, LAST_VALUE",
                "DATE_BIN for time bucketing",
                "DISTINCT for unique values"
            ])
            referenceGroup("Multiple Fields", [
                "SELECT time, temp, humidity",
                "  FROM \"sensors\"",
                "  WHERE time >= NOW() - INTERVAL '2 hours'",
                "  ORDER BY time"
            ])
        }
    }

    private var promqlReference: some View {
        Section("PromQL Reference") {
            referenceGroup("Basic Query", [
                "metric_name",
                "metric_name{label=\"value\"}",
                "metric_name{job=~\"api.*\"}"
            ])
            referenceGroup("Rate & Increase", [
                "rate(http_requests_total[5m])",
                "increase(errors_total[1h])",
                "irate(cpu_usage[5m])"
            ])
            referenceGroup("Aggregation", [
                "sum(metric_name) by (label)",
                "avg(metric_name) by (job)",
                "max(metric_name)",
                "count(metric_name)"
            ])
            referenceGroup("Math", [
                "metric_a / metric_b",
                "metric_name * 100",
                "metric_name offset 1h"
            ])
            referenceGroup("Functions", [
                "histogram_quantile(0.95, ...)",
                "delta(metric_name[5m])",
                "predict_linear(metric[1h], 3600)"
            ])
        }
    }

    private func referenceGroup(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(lines.joined(separator: "\n"))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func loadExisting() {
        guard let q = existingQuery else { return }
        queryName = q.wrappedName
        queryText = q.wrappedRawQuery
        let u = q.wrappedUnit
        let presets = ["°C", "°F", "%", "hPa", "W", "kW", "kWh", "V", "A", "m/s", "km/h", "m", "km", "s", "min", "L"]
        if presets.contains(u) { selectedUnit = u } else if !u.isEmpty { customUnit = u }
    }

    private func saveQuery() {
        let target = existingQuery ?? SavedQuery(context: viewContext)
        if existingQuery == nil {
            target.id = UUID()
            target.createdAt = Date()
            target.dataSource = dataSource
        }
        target.name = queryName
        target.rawQuery = queryText
        target.isRawQuery = true
        target.unit = effectiveUnit.isEmpty ? nil : effectiveUnit
        target.modifiedAt = Date()
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
        dismiss()
    }
}
