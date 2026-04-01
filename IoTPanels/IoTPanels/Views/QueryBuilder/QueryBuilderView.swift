import SwiftUI

struct QueryBuilderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let dataSource: DataSource
    let existingQuery: SavedQuery?
    var defaultName: String = ""

    @State private var queryName = ""
    @State private var selectedMeasurement = ""
    @State private var measurements: [String] = []
    @State private var isLoadingMeasurements = false
    @State private var availableFields: [String] = []
    @State private var selectedFields: Set<String> = []
    @State private var isLoadingFields = false
    @State private var availableTagKeys: [String] = []
    @State private var tagValues: [String: [String]] = [:]
    @State private var selectedTagValues: [String: Set<String>] = [:]
    @State private var isLoadingTags = false
    @State private var timeRange: TimeRange = .twoHours
    @State private var aggregateWindow: AggregateWindow = .fiveMinutes
    @State private var aggregateFunction: AggregateFunction = .mean
    @State private var selectedUnit: String = ""
    @State private var customUnit: String = ""
    @State private var errorMessage: String?
    @State private var didInitialLoad = false

    private var service: any DataSourceServiceProtocol { ServiceFactory.service(for: dataSource) }
    private var effectiveUnit: String { customUnit.isEmpty ? selectedUnit : customUnit }
    private var canSave: Bool { !queryName.isEmpty && !selectedMeasurement.isEmpty && !selectedFields.isEmpty }

    private var selectedFilterCount: Int {
        selectedTagValues.values.reduce(0) { $0 + $1.count }
    }

    @FocusState private var nameFieldFocused: Bool

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

                // Measurement
                Section {
                    NavigationLink {
                        MeasurementPickerPage(
                            measurements: measurements,
                            isLoading: isLoadingMeasurements,
                            selection: $selectedMeasurement,
                            onSelect: { m in selectMeasurement(m) }
                        )
                    } label: {
                        summaryRow(
                            icon: "list.bullet",
                            title: "Measurement",
                            value: selectedMeasurement.isEmpty ? nil : selectedMeasurement,
                            done: !selectedMeasurement.isEmpty
                        )
                    }
                }

                // Fields (only after measurement)
                if !selectedMeasurement.isEmpty {
                    Section {
                        NavigationLink {
                            FieldPickerPage(
                                fields: availableFields,
                                isLoading: isLoadingFields,
                                selection: $selectedFields
                            )
                        } label: {
                            summaryRow(
                                icon: "number",
                                title: "Fields",
                                value: selectedFields.isEmpty ? nil : selectedFields.sorted().joined(separator: ", "),
                                done: !selectedFields.isEmpty
                            )
                        }
                    }

                    // Filters
                    Section {
                        NavigationLink {
                            FilterPickerPage(
                                tagKeys: availableTagKeys,
                                tagValues: $tagValues,
                                selectedTagValues: $selectedTagValues,
                                isLoading: isLoadingTags,
                                measurement: selectedMeasurement,
                                service: service
                            )
                        } label: {
                            summaryRow(
                                icon: "line.3.horizontal.decrease",
                                title: "Filters",
                                value: selectedFilterCount > 0 ? "\(selectedFilterCount) active" : nil,
                                done: selectedFilterCount > 0,
                                optional: true
                            )
                        }
                    }

                    // Time & Aggregation
                    Section {
                        NavigationLink {
                            TimeAggregationPage(
                                timeRange: $timeRange,
                                aggregateWindow: $aggregateWindow,
                                aggregateFunction: $aggregateFunction
                            )
                        } label: {
                            summaryRow(
                                icon: "clock",
                                title: "Time & Aggregation",
                                value: "\(timeRange.displayName) · \(aggregateWindow.displayName)",
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
                            QueryPreviewPage(flux: buildPreviewQuery(), service: service)
                        } label: {
                            Label("Preview Query", systemImage: "play.circle")
                        }
                    }
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
            .onAppear {
                guard !didInitialLoad else { return }
                didInitialLoad = true
                loadExistingQuery()
                loadMeasurements()
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

    // MARK: - Actions

    private func selectMeasurement(_ m: String) {
        let changed = selectedMeasurement != m
        selectedMeasurement = m
        if changed {
            selectedFields = []
            availableFields = []
            availableTagKeys = []
            tagValues = [:]
            selectedTagValues = [:]
            loadFields(measurement: m)
            loadTagKeys(measurement: m)
        }
        if queryName.isEmpty { queryName = m }
    }

    private func loadMeasurements() {
        isLoadingMeasurements = true
        Task {
            do {
                let result = try await service.fetchMeasurements()
                await MainActor.run { measurements = result; isLoadingMeasurements = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoadingMeasurements = false }
            }
        }
    }

    private func loadFields(measurement: String) {
        isLoadingFields = true
        Task {
            do {
                let result = try await service.fetchFieldKeys(measurement: measurement)
                await MainActor.run {
                    availableFields = result
                    isLoadingFields = false
                    if result.count == 1 {
                        selectedFields = Set(result)
                    }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoadingFields = false }
            }
        }
    }

    private func loadTagKeys(measurement: String) {
        isLoadingTags = true
        Task {
            do {
                let result = try await service.fetchTagKeys(measurement: measurement)
                await MainActor.run { availableTagKeys = result; isLoadingTags = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoadingTags = false }
            }
        }
    }

    private func buildPreviewQuery() -> String {
        if dataSource.wrappedBackendType == .influxDB3 {
            return buildSQLPreviewQuery()
        }
        return buildFluxPreviewQuery()
    }

    private func buildFluxPreviewQuery() -> String {
        var query = """
        from(bucket: "\(dataSource.wrappedBucket)")
          |> range(start: \(timeRange.fluxValue))
          |> filter(fn: (r) => r["_measurement"] == "\(selectedMeasurement)")
        """
        if !selectedFields.isEmpty {
            let f = selectedFields.sorted().map { "r[\"_field\"] == \"\($0)\"" }.joined(separator: " or ")
            query += "\n  |> filter(fn: (r) => \(f))"
        }
        for (k, v) in selectedTagValues where !v.isEmpty {
            let f = v.sorted().map { "r[\"\(k)\"] == \"\($0)\"" }.joined(separator: " or ")
            query += "\n  |> filter(fn: (r) => \(f))"
        }
        if aggregateWindow != .none {
            query += "\n  |> aggregateWindow(every: \(aggregateWindow.rawValue), fn: \(aggregateFunction.rawValue), createEmpty: false)"
        }
        query += "\n  |> yield(name: \"results\")"
        return query
    }

    private func buildSQLPreviewQuery() -> String {
        let fields = selectedFields.isEmpty ? "*" : selectedFields.sorted().map { "\"\($0)\"" }.joined(separator: ", ")
        var query = "SELECT time, \(fields)\nFROM \"\(selectedMeasurement)\"\nWHERE time >= NOW() - INTERVAL '\(Int(timeRange.seconds)) seconds'"
        for (k, v) in selectedTagValues where !v.isEmpty {
            let values = v.sorted().map { "'\($0)'" }.joined(separator: ", ")
            query += "\n  AND \"\(k)\" IN (\(values))"
        }
        if aggregateWindow != .none {
            // Simplified preview — actual query uses DATE_BIN
            query = "SELECT DATE_BIN(INTERVAL '\(Int(aggregateWindow.seconds)) seconds', time) AS time, \(selectedFields.sorted().map { "AVG(\"\($0)\") AS \"\($0)\"" }.joined(separator: ", "))\nFROM \"\(selectedMeasurement)\"\nWHERE time >= NOW() - INTERVAL '\(Int(timeRange.seconds)) seconds'"
            for (k, v) in selectedTagValues where !v.isEmpty {
                let values = v.sorted().map { "'\($0)'" }.joined(separator: ", ")
                query += "\n  AND \"\(k)\" IN (\(values))"
            }
            query += "\nGROUP BY 1\nORDER BY 1"
        } else {
            query += "\nORDER BY time"
        }
        return query
    }

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
        selectedMeasurement = q.wrappedMeasurement
        selectedFields = Set(q.wrappedFields)
        selectedTagValues = q.wrappedTagFilters.mapValues { Set($0) }
        timeRange = q.wrappedTimeRange
        aggregateWindow = q.wrappedAggregateWindow
        aggregateFunction = q.wrappedAggregateFunction
        let u = q.wrappedUnit
        let presets = ["°C", "°F", "%", "hPa", "W", "kW", "kWh", "V", "A", "m/s", "km/h", "m", "km", "s", "min", "L"]
        if presets.contains(u) { selectedUnit = u } else if !u.isEmpty { customUnit = u }
        if !selectedMeasurement.isEmpty {
            loadFields(measurement: selectedMeasurement)
            loadTagKeys(measurement: selectedMeasurement)
        }
    }
}

// MARK: - Measurement Picker Page

struct MeasurementPickerPage: View {
    let measurements: [String]
    let isLoading: Bool
    @Binding var selection: String
    let onSelect: (String) -> Void
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if isLoading {
                HStack { ProgressView(); Text("Loading...").padding(.leading, 8) }
            } else {
                ForEach(filtered, id: \.self) { m in
                    Button {
                        onSelect(m)
                        dismiss()
                    } label: {
                        HStack {
                            Text(m).foregroundStyle(.primary)
                            Spacer()
                            if selection == m {
                                Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search measurements")
        .navigationTitle("Measurement")
    }

    private var filtered: [String] {
        search.isEmpty ? measurements : measurements.filter { $0.localizedCaseInsensitiveContains(search) }
    }
}

// MARK: - Field Picker Page

struct FieldPickerPage: View {
    let fields: [String]
    let isLoading: Bool
    @Binding var selection: Set<String>

    var body: some View {
        List {
            if isLoading {
                HStack { ProgressView(); Text("Loading...").padding(.leading, 8) }
            } else {
                ForEach(fields, id: \.self) { field in
                    Button {
                        if selection.contains(field) { selection.remove(field) } else { selection.insert(field) }
                    } label: {
                        HStack {
                            Text(field).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: selection.contains(field) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selection.contains(field) ? Color.accentColor : .secondary)
                        }
                    }
                }
            }

            if !selection.isEmpty {
                Section("Selected") {
                    Text(selection.sorted().joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Fields")
    }
}

// MARK: - Filter Picker Page

struct FilterPickerPage: View {
    let tagKeys: [String]
    @Binding var tagValues: [String: [String]]
    @Binding var selectedTagValues: [String: Set<String>]
    let isLoading: Bool
    let measurement: String
    let service: any DataSourceServiceProtocol

    @State private var expandedTag: String?

    var body: some View {
        List {
            if isLoading {
                HStack { ProgressView(); Text("Loading...").padding(.leading, 8) }
            } else if tagKeys.isEmpty {
                Text("No tags available").foregroundStyle(.secondary)
            } else {
                ForEach(tagKeys, id: \.self) { tagKey in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedTag == tagKey },
                            set: { expanded in
                                expandedTag = expanded ? tagKey : nil
                                if expanded && tagValues[tagKey] == nil {
                                    loadValues(tag: tagKey)
                                }
                            }
                        )
                    ) {
                        if let values = tagValues[tagKey] {
                            ForEach(values, id: \.self) { value in
                                Button {
                                    toggle(tagKey: tagKey, value: value)
                                } label: {
                                    HStack {
                                        Text(value).foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: selectedTagValues[tagKey]?.contains(value) == true ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedTagValues[tagKey]?.contains(value) == true ? Color.accentColor : .secondary)
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
                            if let sel = selectedTagValues[tagKey], !sel.isEmpty {
                                Text("\(sel.count)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Filters")
    }

    private func toggle(tagKey: String, value: String) {
        if selectedTagValues[tagKey] == nil { selectedTagValues[tagKey] = [] }
        if selectedTagValues[tagKey]!.contains(value) {
            selectedTagValues[tagKey]!.remove(value)
        } else {
            selectedTagValues[tagKey]!.insert(value)
        }
    }

    private func loadValues(tag: String) {
        Task {
            do {
                let result = try await service.fetchTagValues(measurement: measurement, tag: tag)
                await MainActor.run { tagValues[tag] = result }
            } catch {}
        }
    }
}

// MARK: - Time & Aggregation Page

struct TimeAggregationPage: View {
    @Binding var timeRange: TimeRange
    @Binding var aggregateWindow: AggregateWindow
    @Binding var aggregateFunction: AggregateFunction

    var body: some View {
        Form {
            Section("Time Range") {
                Picker("Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { r in Text(r.displayName).tag(r) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: timeRange) {
                    let allowed = timeRange.allowedWindows
                    if !allowed.contains(aggregateWindow) {
                        aggregateWindow = timeRange.minimumWindow
                    }
                }
            }

            Section("Aggregate Window") {
                Picker("Window", selection: $aggregateWindow) {
                    ForEach(timeRange.allowedWindows) { w in Text(w.displayName).tag(w) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            if aggregateWindow != .none {
                Section("Aggregate Function") {
                    Picker("Function", selection: $aggregateFunction) {
                        ForEach(AggregateFunction.allCases) { fn in Text(fn.displayName).tag(fn) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        }
        .navigationTitle("Time & Aggregation")
    }
}

// MARK: - Unit Picker Page

struct UnitPickerPage: View {
    @Binding var selectedUnit: String
    @Binding var customUnit: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var effectiveUnit: String { customUnit.isEmpty ? selectedUnit : customUnit }

    private struct UnitGroup: Identifiable {
        let id: String
        let name: String
        let icon: String
        let units: [(symbol: String, label: String)]
    }

    private let groups: [UnitGroup] = [
        UnitGroup(id: "temp", name: "Temperature", icon: "thermometer", units: [
            ("°C", "Celsius"), ("°F", "Fahrenheit"), ("K", "Kelvin")
        ]),
        UnitGroup(id: "humidity", name: "Humidity", icon: "humidity", units: [
            ("%RH", "Relative Humidity"), ("%", "Percent")
        ]),
        UnitGroup(id: "pressure", name: "Pressure", icon: "gauge.with.dots.needle.bottom.50percent", units: [
            ("hPa", "Hectopascal"), ("mbar", "Millibar"), ("Pa", "Pascal"),
            ("mmHg", "mm Mercury"), ("psi", "Pounds/sq inch")
        ]),
        UnitGroup(id: "power", name: "Power & Energy", icon: "bolt", units: [
            ("W", "Watt"), ("kW", "Kilowatt"), ("MW", "Megawatt"),
            ("Wh", "Watt-hour"), ("kWh", "Kilowatt-hour"), ("MWh", "Megawatt-hour")
        ]),
        UnitGroup(id: "electrical", name: "Electrical", icon: "powerplug", units: [
            ("V", "Volt"), ("mV", "Millivolt"),
            ("A", "Ampere"), ("mA", "Milliampere")
        ]),
        UnitGroup(id: "speed", name: "Speed", icon: "speedometer", units: [
            ("m/s", "Meters/second"), ("km/h", "Kilometers/hour"), ("mph", "Miles/hour"), ("kn", "Knots")
        ]),
        UnitGroup(id: "distance", name: "Distance", icon: "ruler", units: [
            ("m", "Meter"), ("km", "Kilometer"), ("cm", "Centimeter"), ("mm", "Millimeter"),
            ("mi", "Mile"), ("ft", "Foot"), ("in", "Inch")
        ]),
        UnitGroup(id: "time", name: "Time", icon: "clock", units: [
            ("s", "Seconds"), ("ms", "Milliseconds"), ("min", "Minutes"), ("h", "Hours"), ("d", "Days")
        ]),
        UnitGroup(id: "volume", name: "Volume", icon: "drop", units: [
            ("L", "Liter"), ("mL", "Milliliter"), ("m³", "Cubic meter"), ("gal", "Gallon")
        ]),
        UnitGroup(id: "other", name: "Other", icon: "number", units: [
            ("%", "Percent"), ("dB", "Decibel"), ("ppm", "Parts per million"), ("lx", "Lux"), ("µg/m³", "Microgram/m³")
        ]),
    ]

    private var filteredGroups: [UnitGroup] {
        guard !searchText.isEmpty else { return groups }
        let query = searchText.lowercased()
        return groups.compactMap { group in
            let matched = group.units.filter {
                $0.symbol.lowercased().contains(query) || $0.label.lowercased().contains(query)
            }
            if matched.isEmpty && !group.name.lowercased().contains(query) { return nil }
            let units = matched.isEmpty ? group.units : matched
            return UnitGroup(id: group.id, name: group.name, icon: group.icon, units: units)
        }
    }

    var body: some View {
        List {
            // Current
            if !effectiveUnit.isEmpty && searchText.isEmpty {
                Section {
                    HStack {
                        Text("Current unit")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(effectiveUnit)
                            .fontWeight(.semibold)
                    }
                    Button("Clear unit", role: .destructive) {
                        selectedUnit = ""
                        customUnit = ""
                    }
                }
            }

            // Groups
            ForEach(filteredGroups) { group in
                Section {
                    ForEach(group.units, id: \.symbol) { unit in
                        Button {
                            selectedUnit = unit.symbol
                            customUnit = ""
                            dismiss()
                        } label: {
                            HStack {
                                Text(unit.symbol)
                                    .font(.body.weight(.medium).monospacedDigit())
                                    .frame(width: 50, alignment: .leading)
                                Text(unit.label)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if selectedUnit == unit.symbol && customUnit.isEmpty {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Label(group.name, systemImage: group.icon)
                }
            }

            // Custom
            if searchText.isEmpty {
                Section {
                    TextField("Custom unit (e.g. rpm, bar)", text: $customUnit)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: customUnit) {
                            if !customUnit.isEmpty { selectedUnit = "" }
                        }
                } header: {
                    Label("Custom", systemImage: "pencil")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search units")
        .navigationTitle("Unit")
    }
}

// MARK: - Query Preview Page

struct QueryPreviewPage: View {
    let flux: String
    let service: any DataSourceServiceProtocol

    @State private var result: QueryResult?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Flux Query") {
                FluxSyntaxView(flux, fontSize: 10)
            }

            Section {
                Button(action: runPreview) {
                    HStack {
                        Label("Run Preview", systemImage: "play.fill")
                        Spacer()
                        if isLoading { ProgressView() }
                    }
                }
                .disabled(isLoading)
            }

            if let result {
                Section("\(result.rows.count) rows") {
                    QueryResultTableView(result: result)
                        .frame(minHeight: 200)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Preview")
        .onAppear { runPreview() }
    }

    private func runPreview() {
        isLoading = true
        errorMessage = nil
        let previewFlux = flux.replacingOccurrences(
            of: "|> yield(name: \"results\")",
            with: "|> limit(n: 100)\n  |> yield(name: \"results\")"
        )
        Task {
            do {
                let r = try await service.query(previewFlux)
                await MainActor.run { result = r; isLoading = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
            }
        }
    }
}
