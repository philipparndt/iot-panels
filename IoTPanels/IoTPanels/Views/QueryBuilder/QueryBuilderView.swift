import SwiftUI

struct QueryBuilderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let dataSource: DataSource
    let existingQuery: SavedQuery?

    enum Step: Int, CaseIterable {
        case measurement = 0
        case fields = 1
        case filters = 2
        case timeAggregation = 3
        case preview = 4

        var title: String {
            switch self {
            case .measurement: return "Measurement"
            case .fields: return "Fields"
            case .filters: return "Filters"
            case .timeAggregation: return "Time"
            case .preview: return "Preview"
            }
        }

        var previous: Step? {
            Step(rawValue: rawValue - 1)
        }

        var next: Step? {
            Step(rawValue: rawValue + 1)
        }
    }

    @State private var step: Step = .measurement
    @State private var queryName = ""

    // Measurement
    @State private var measurements: [String] = []
    @State private var selectedMeasurement = ""
    @State private var isLoadingMeasurements = false

    // Fields
    @State private var availableFields: [String] = []
    @State private var selectedFields: Set<String> = []
    @State private var isLoadingFields = false
    @State private var fieldsLoadedForMeasurement = ""

    // Tags
    @State private var availableTagKeys: [String] = []
    @State private var tagValues: [String: [String]] = [:]
    @State private var selectedTagValues: [String: Set<String>] = [:]
    @State private var expandedTag: String?
    @State private var isLoadingTags = false
    @State private var tagsLoadedForMeasurement = ""

    // Time & Aggregation
    @State private var timeRange: TimeRange = .oneHour
    @State private var aggregateWindow: AggregateWindow = .fiveMinutes
    @State private var aggregateFunction: AggregateFunction = .mean

    // Preview
    @State private var previewResult: QueryResult?
    @State private var isLoadingPreview = false
    @State private var errorMessage: String?

    private var service: InfluxDB2Service {
        InfluxDB2Service(dataSource: dataSource)
    }

    private var canGoBack: Bool {
        step.previous != nil
    }

    private var canGoForward: Bool {
        switch step {
        case .measurement: return !selectedMeasurement.isEmpty
        case .fields: return !selectedFields.isEmpty
        case .filters: return true
        case .timeAggregation: return true
        case .preview: return false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.horizontal)
                    .padding(.top)

                Form {
                    switch step {
                    case .measurement:
                        measurementStep
                    case .fields:
                        fieldsStep
                    case .filters:
                        filtersStep
                    case .timeAggregation:
                        timeStep
                    case .preview:
                        previewStep
                    }

                    if let errorMessage {
                        Section {
                            Label(errorMessage, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                navigationBar
            }
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                loadExistingQuery()
                if measurements.isEmpty {
                    loadMeasurements()
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Button {
                    if s.rawValue < step.rawValue {
                        navigateTo(step: s)
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(s.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                                .frame(width: 24, height: 24)
                            Text("\(s.rawValue + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(s.rawValue <= step.rawValue ? .white : .secondary)
                        }
                        Text(s.title)
                            .font(.system(size: 9))
                            .foregroundStyle(s.rawValue <= step.rawValue ? .primary : .secondary)
                    }
                }
                .disabled(s.rawValue > step.rawValue)

                if s.rawValue < Step.allCases.count - 1 {
                    Rectangle()
                        .fill(s.rawValue < step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 2)
                        .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            if canGoBack {
                Button {
                    goBack()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }

            Spacer()

            if step == .preview {
                Button {
                    saveQuery()
                } label: {
                    Text("Save")
                        .fontWeight(.semibold)
                }
                .disabled(queryName.isEmpty)
            } else if canGoForward {
                Button {
                    goForward()
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Navigation

    private func goBack() {
        guard let prev = step.previous else { return }
        withAnimation { step = prev }
    }

    private func goForward() {
        guard let next = step.next else { return }
        errorMessage = nil

        switch step {
        case .measurement:
            if fieldsLoadedForMeasurement != selectedMeasurement {
                selectedFields = []
                availableFields = []
                availableTagKeys = []
                tagValues = [:]
                selectedTagValues = [:]
                expandedTag = nil
                tagsLoadedForMeasurement = ""
                loadFields(measurement: selectedMeasurement)
            }
            withAnimation { step = next }
        case .fields:
            if tagsLoadedForMeasurement != selectedMeasurement {
                availableTagKeys = []
                tagValues = [:]
                selectedTagValues = [:]
                expandedTag = nil
                loadTagKeys(measurement: selectedMeasurement)
            }
            withAnimation { step = next }
        case .filters:
            withAnimation { step = next }
        case .timeAggregation:
            if queryName.isEmpty {
                let fields = selectedFields.sorted().joined(separator: ", ")
                queryName = "\(selectedMeasurement) — \(fields)"
            }
            withAnimation { step = next }
            runPreview()
        case .preview:
            break
        }
    }

    private func navigateTo(step target: Step) {
        withAnimation { step = target }
    }

    // MARK: - Measurement Step

    @ViewBuilder
    private var measurementStep: some View {
        Section("Select Measurement") {
            if isLoadingMeasurements {
                ProgressView("Loading measurements...")
            } else {
                ForEach(Array(measurements.enumerated()), id: \.element) { _, m in
                    Button {
                        selectedMeasurement = m
                    } label: {
                        HStack {
                            Text(m)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedMeasurement == m {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Fields Step

    @ViewBuilder
    private var fieldsStep: some View {
        Section {
            if isLoadingFields {
                ProgressView("Loading fields...")
            } else {
                ForEach(Array(availableFields.enumerated()), id: \.element) { _, field in
                    Button {
                        if selectedFields.contains(field) {
                            selectedFields.remove(field)
                        } else {
                            selectedFields.insert(field)
                        }
                    } label: {
                        HStack {
                            Text(field)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedFields.contains(field) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Select Fields")
        } footer: {
            Text("Select one or more fields to include in the query.")
        }
    }

    // MARK: - Filters Step

    @ViewBuilder
    private var filtersStep: some View {
        Section {
            if isLoadingTags {
                ProgressView("Loading tags...")
            } else if availableTagKeys.isEmpty {
                Text("No tags available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(availableTagKeys.enumerated()), id: \.element) { _, tagKey in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedTag == tagKey },
                            set: { expanded in
                                expandedTag = expanded ? tagKey : nil
                                if expanded && tagValues[tagKey] == nil {
                                    loadTagValues(measurement: selectedMeasurement, tag: tagKey)
                                }
                            }
                        )
                    ) {
                        if let values = tagValues[tagKey] {
                            ForEach(Array(values.enumerated()), id: \.element) { _, value in
                                Button {
                                    toggleTagValue(tagKey: tagKey, value: value)
                                } label: {
                                    HStack {
                                        Text(value)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedTagValues[tagKey]?.contains(value) == true {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.accentColor)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } else {
                            ProgressView()
                        }
                    } label: {
                        HStack {
                            Text(tagKey)
                            Spacer()
                            if let selected = selectedTagValues[tagKey], !selected.isEmpty {
                                Text("\(selected.count)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Filter by Tags (optional)")
        } footer: {
            Text("Expand a tag to select filter values. You can skip this step.")
        }
    }

    // MARK: - Time & Aggregation Step

    @ViewBuilder
    private var timeStep: some View {
        Section("Time Range") {
            Picker("Range", selection: $timeRange) {
                ForEach(TimeRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
        }

        Section("Aggregation") {
            Picker("Window", selection: $aggregateWindow) {
                ForEach(AggregateWindow.allCases) { window in
                    Text(window.displayName).tag(window)
                }
            }

            if aggregateWindow != .none {
                Picker("Function", selection: $aggregateFunction) {
                    ForEach(AggregateFunction.allCases) { fn in
                        Text(fn.displayName).tag(fn)
                    }
                }
            }
        }
    }

    // MARK: - Preview Step

    @ViewBuilder
    private var previewStep: some View {
        Section {
            TextField("Enter a name to save", text: $queryName)
        } header: {
            Text("Query Name")
        } footer: {
            if queryName.isEmpty {
                Text("A name is required to save the query.")
                    .foregroundStyle(.red)
            }
        }

        Section("Flux Query") {
            Text(buildFluxQuery())
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }

        if isLoadingPreview {
            Section {
                HStack {
                    ProgressView()
                    Text("Running query...")
                        .padding(.leading, 8)
                }
            }
        } else if let result = previewResult {
            Section("Results (\(result.rows.count) rows)") {
                QueryResultTableView(result: result)
                    .frame(minHeight: 200)
            }
        }
    }

    // MARK: - Data Loading

    private func loadMeasurements() {
        isLoadingMeasurements = true
        errorMessage = nil
        Task {
            do {
                let result = try await service.fetchMeasurements()
                await MainActor.run {
                    measurements = result
                    isLoadingMeasurements = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingMeasurements = false
                }
            }
        }
    }

    private func loadFields(measurement: String) {
        isLoadingFields = true
        errorMessage = nil
        Task {
            do {
                let result = try await service.fetchFieldKeys(measurement: measurement)
                await MainActor.run {
                    availableFields = result
                    fieldsLoadedForMeasurement = measurement
                    isLoadingFields = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingFields = false
                }
            }
        }
    }

    private func loadTagKeys(measurement: String) {
        isLoadingTags = true
        errorMessage = nil
        Task {
            do {
                let result = try await service.fetchTagKeys(measurement: measurement)
                await MainActor.run {
                    availableTagKeys = result
                    tagsLoadedForMeasurement = measurement
                    isLoadingTags = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingTags = false
                }
            }
        }
    }

    private func loadTagValues(measurement: String, tag: String) {
        Task {
            do {
                let result = try await service.fetchTagValues(measurement: measurement, tag: tag)
                await MainActor.run {
                    tagValues[tag] = result
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func toggleTagValue(tagKey: String, value: String) {
        if selectedTagValues[tagKey] == nil {
            selectedTagValues[tagKey] = []
        }
        if selectedTagValues[tagKey]!.contains(value) {
            selectedTagValues[tagKey]!.remove(value)
        } else {
            selectedTagValues[tagKey]!.insert(value)
        }
    }

    // MARK: - Query Building

    private func buildFluxQuery() -> String {
        var query = """
        from(bucket: "\(dataSource.wrappedBucket)")
          |> range(start: \(timeRange.fluxValue))
          |> filter(fn: (r) => r["_measurement"] == "\(selectedMeasurement)")
        """

        if !selectedFields.isEmpty {
            let fieldFilter = selectedFields.sorted()
                .map { "r[\"_field\"] == \"\($0)\"" }
                .joined(separator: " or ")
            query += "\n  |> filter(fn: (r) => \(fieldFilter))"
        }

        for (tagKey, tagVals) in selectedTagValues where !tagVals.isEmpty {
            let tagFilter = tagVals.sorted()
                .map { "r[\"\(tagKey)\"] == \"\($0)\"" }
                .joined(separator: " or ")
            query += "\n  |> filter(fn: (r) => \(tagFilter))"
        }

        if aggregateWindow != .none {
            query += "\n  |> aggregateWindow(every: \(aggregateWindow.rawValue), fn: \(aggregateFunction.rawValue), createEmpty: false)"
        }

        query += "\n  |> yield(name: \"results\")"
        return query
    }

    private func runPreview() {
        isLoadingPreview = true
        errorMessage = nil
        let flux = buildFluxQuery().replacingOccurrences(
            of: "|> yield(name: \"results\")",
            with: "|> limit(n: 100)\n  |> yield(name: \"results\")"
        )
        Task {
            do {
                let result = try await service.query(flux)
                await MainActor.run {
                    previewResult = result
                    isLoadingPreview = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingPreview = false
                }
            }
        }
    }

    // MARK: - Save

    private func saveQuery() {
        let target = existingQuery ?? SavedQuery(context: viewContext)

        if existingQuery == nil {
            target.id = UUID()
            target.createdAt = Date()
            target.dataSource = dataSource
        }

        target.name = queryName
        target.measurement = selectedMeasurement
        target.wrappedFields = Array(selectedFields)
        target.wrappedTagFilters = selectedTagValues.mapValues { Array($0) }
        target.timeRange = timeRange.rawValue
        target.aggregateWindow = aggregateWindow.rawValue
        target.aggregateFunction = aggregateFunction.rawValue
        target.modifiedAt = Date()

        try? viewContext.save()
        WidgetHelper.reloadWidgets()
        dismiss()
    }

    // MARK: - Load Existing

    private func loadExistingQuery() {
        guard let q = existingQuery else { return }
        queryName = q.wrappedName
        selectedMeasurement = q.wrappedMeasurement
        selectedFields = Set(q.wrappedFields)
        selectedTagValues = q.wrappedTagFilters.mapValues { Set($0) }
        timeRange = q.wrappedTimeRange
        aggregateWindow = q.wrappedAggregateWindow
        aggregateFunction = q.wrappedAggregateFunction
    }
}
