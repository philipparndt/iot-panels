import SwiftUI

struct PrometheusQueryBuilderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let dataSource: DataSource
    let existingQuery: SavedQuery?
    var defaultName: String = ""

    @State private var queryName = ""
    @State private var isRawMode = false
    @State private var rawQuery = ""

    // Guided mode
    @State private var selectedMetric = ""
    @State private var metrics: [String] = []
    @State private var isLoadingMetrics = false
    @State private var availableLabelKeys: [String] = []
    @State private var labelValues: [String: [String]] = [:]
    @State private var selectedLabelValues: [String: Set<String>] = [:]
    @State private var isLoadingLabels = false
    @State private var selectedAggregateFunction = "none"
    @State private var timeRange: TimeRange = .twoHours
    @State private var aggregateWindow: AggregateWindow = .fiveMinutes
    @State private var selectedUnit: String = ""
    @State private var customUnit: String = ""
    @State private var errorMessage: String?
    @State private var didInitialLoad = false

    @FocusState private var nameFieldFocused: Bool

    private var service: any DataSourceServiceProtocol { ServiceFactory.service(for: dataSource) }
    private var effectiveUnit: String { customUnit.isEmpty ? selectedUnit : customUnit }

    private var canSave: Bool {
        !queryName.isEmpty && (isRawMode ? !rawQuery.isEmpty : !selectedMetric.isEmpty)
    }

    private var selectedFilterCount: Int {
        selectedLabelValues.values.reduce(0) { $0 + $1.count }
    }

    private let aggregateFunctions = [
        ("none", "None"),
        ("avg", "Average"),
        ("sum", "Sum"),
        ("min", "Minimum"),
        ("max", "Maximum"),
        ("count", "Count")
    ]

    var body: some View {
        NavigationStack {
            List {
                // Name
                Section {
                    TextField("Query name", text: $queryName)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFieldFocused = false }
                }

                // Mode toggle
                Section {
                    Toggle("Raw PromQL", isOn: $isRawMode)
                        .onChange(of: isRawMode) {
                            if isRawMode && rawQuery.isEmpty {
                                rawQuery = buildPromQL()
                            }
                        }
                }

                if isRawMode {
                    rawQuerySection
                } else {
                    guidedQuerySection
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(existingQuery != nil ? "Edit Query" : "New Query")
            .inlineNavigationTitle()
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
            .onAppear {
                guard !didInitialLoad else { return }
                didInitialLoad = true
                loadExistingQuery()
                loadMetrics()
            }
        }
    }

    // MARK: - Raw Query Section

    @ViewBuilder
    private var rawQuerySection: some View {
        Section {
            TextEditor(text: $rawQuery)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
        } header: {
            Text("PromQL")
        } footer: {
            Text("Enter a valid PromQL expression (e.g., rate(http_requests_total[5m]))")
        }

        // Time & Aggregation
        Section {
            NavigationLink {
                TimeAggregationPage(
                    timeRange: $timeRange,
                    aggregateWindow: $aggregateWindow,
                    aggregateFunction: .constant(.mean)
                )
            } label: {
                summaryRow(
                    icon: "clock",
                    title: "Time Range",
                    value: timeRange.displayName,
                    done: true
                )
            }
        }

        // Unit
        Section {
            NavigationLink {
                UnitPickerPage(
                    selectedUnit: $selectedUnit,
                    customUnit: $customUnit
                )
            } label: {
                summaryRow(
                    icon: "textformat.123",
                    title: "Unit",
                    value: effectiveUnit.isEmpty ? nil : effectiveUnit,
                    done: !effectiveUnit.isEmpty,
                    optional: true
                )
            }
        }

        // Preview
        Section {
            NavigationLink {
                QueryPreviewPage(flux: rawQuery, service: service)
            } label: {
                Label("Preview Query", systemImage: "play.circle")
            }
        }
    }

    // MARK: - Guided Query Section

    @ViewBuilder
    private var guidedQuerySection: some View {
        // Metric
        Section {
            NavigationLink {
                MeasurementPickerPage(
                    measurements: metrics,
                    isLoading: isLoadingMetrics,
                    selection: $selectedMetric,
                    onSelect: { m in selectMetric(m) }
                )
            } label: {
                summaryRow(
                    icon: "list.bullet",
                    title: "Metric",
                    value: selectedMetric.isEmpty ? nil : selectedMetric,
                    done: !selectedMetric.isEmpty
                )
            }
        }

        if !selectedMetric.isEmpty {
            // Label Filters
            Section {
                NavigationLink {
                    FilterPickerPage(
                        tagKeys: availableLabelKeys,
                        tagValues: $labelValues,
                        selectedTagValues: $selectedLabelValues,
                        isLoading: isLoadingLabels,
                        measurement: selectedMetric,
                        service: service
                    )
                } label: {
                    summaryRow(
                        icon: "line.3.horizontal.decrease",
                        title: "Label Filters",
                        value: selectedFilterCount > 0 ? "\(selectedFilterCount) active" : nil,
                        done: selectedFilterCount > 0,
                        optional: true
                    )
                }
            }

            // Aggregate Function
            Section {
                Picker("Aggregate", selection: $selectedAggregateFunction) {
                    ForEach(aggregateFunctions, id: \.0) { fn in
                        Text(fn.1).tag(fn.0)
                    }
                }
            }

            // Time & Aggregation
            Section {
                NavigationLink {
                    TimeAggregationPage(
                        timeRange: $timeRange,
                        aggregateWindow: $aggregateWindow,
                        aggregateFunction: .constant(.mean)
                    )
                } label: {
                    summaryRow(
                        icon: "clock",
                        title: "Time Range",
                        value: timeRange.displayName,
                        done: true
                    )
                }
            }

            // Unit
            Section {
                NavigationLink {
                    UnitPickerPage(
                        selectedUnit: $selectedUnit,
                        customUnit: $customUnit
                    )
                } label: {
                    summaryRow(
                        icon: "textformat.123",
                        title: "Unit",
                        value: effectiveUnit.isEmpty ? nil : effectiveUnit,
                        done: !effectiveUnit.isEmpty,
                        optional: true
                    )
                }
            }

            // Preview
            Section {
                NavigationLink {
                    QueryPreviewPage(flux: buildPromQL(), service: service)
                } label: {
                    Label("Preview Query", systemImage: "play.circle")
                }
            }
        }
    }

    // MARK: - Summary Row

    private func summaryRow(icon: String, title: String, value: String?, done: Bool, optional: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : (optional ? "circle.dashed" : "circle"))
                .foregroundStyle(done ? .green : (optional ? .secondary : .orange))
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                if let value, !value.isEmpty {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - PromQL Generation

    private func buildPromQL() -> String {
        PromQLBuilder.build(
            metric: selectedMetric,
            labelFilters: selectedLabelValues,
            aggregateFunction: selectedAggregateFunction == "none" ? nil : selectedAggregateFunction
        )
    }

    // MARK: - Actions

    private func selectMetric(_ m: String) {
        let changed = selectedMetric != m
        selectedMetric = m
        if changed {
            availableLabelKeys = []
            labelValues = [:]
            selectedLabelValues = [:]
            loadLabelKeys(metric: m)
        }
        if queryName.isEmpty { queryName = m }
    }

    private func loadMetrics() {
        isLoadingMetrics = true
        Task {
            do {
                let result = try await service.fetchMeasurements()
                await MainActor.run { metrics = result; isLoadingMetrics = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoadingMetrics = false }
            }
        }
    }

    private func loadLabelKeys(metric: String) {
        isLoadingLabels = true
        Task {
            do {
                let result = try await service.fetchTagKeys(measurement: metric)
                await MainActor.run { availableLabelKeys = result; isLoadingLabels = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoadingLabels = false }
            }
        }
    }

    private func saveQuery() {
        let target = existingQuery ?? SavedQuery(context: viewContext)
        if existingQuery == nil {
            target.id = UUID()
            target.createdAt = Date()
            target.dataSource = dataSource
        }
        target.name = queryName
        target.isRawQuery = isRawMode
        if isRawMode {
            target.rawQuery = rawQuery
        } else {
            target.measurement = selectedMetric
            target.wrappedFields = ["value"]
            target.wrappedTagFilters = selectedLabelValues.mapValues { Array($0) }
            target.rawQuery = buildPromQL()
        }
        target.timeRange = timeRange.rawValue
        target.aggregateWindow = aggregateWindow.rawValue
        target.aggregateFunction = selectedAggregateFunction == "none" ? AggregateFunction.mean.rawValue : selectedAggregateFunction
        target.unit = effectiveUnit.isEmpty ? nil : effectiveUnit
        target.modifiedAt = Date()
        try? viewContext.save()
        WidgetHelper.reloadWidgets()
        dismiss()
    }

    private func loadExistingQuery() {
        if existingQuery == nil && !defaultName.isEmpty {
            queryName = defaultName
        }
        guard let q = existingQuery else { return }
        queryName = q.wrappedName
        isRawMode = q.wrappedIsRawQuery
        rawQuery = q.wrappedRawQuery
        selectedMetric = q.wrappedMeasurement
        selectedLabelValues = q.wrappedTagFilters.mapValues { Set($0) }
        timeRange = q.wrappedTimeRange
        aggregateWindow = q.wrappedAggregateWindow
        let u = q.wrappedUnit
        let presets = ["°C", "°F", "%", "hPa", "W", "kW", "kWh", "V", "A", "m/s", "km/h", "m", "km", "s", "min", "L"]
        if presets.contains(u) { selectedUnit = u } else if !u.isEmpty { customUnit = u }
        if !selectedMetric.isEmpty {
            loadLabelKeys(metric: selectedMetric)
        }
    }
}
