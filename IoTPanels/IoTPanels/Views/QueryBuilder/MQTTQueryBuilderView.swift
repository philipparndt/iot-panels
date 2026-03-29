import SwiftUI

/// Query builder for MQTT data sources.
/// Instead of Flux queries, the user selects a topic and fields discovered from JSON payloads.
struct MQTTQueryBuilderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let dataSource: DataSource
    let existingQuery: SavedQuery?
    var defaultName: String = ""

    @State private var queryName = ""
    @State private var selectedTopic = ""
    @State private var topics: [String] = []
    @State private var isLoadingTopics = false
    @State private var availableFields: [String] = []
    @State private var selectedFields: Set<String> = []
    @State private var isLoadingFields = false
    @State private var collectDuration: MQTTCollectDuration = .tenSeconds
    @State private var selectedUnit: String = ""
    @State private var customUnit: String = ""
    @State private var errorMessage: String?
    @State private var didInitialLoad = false

    @FocusState private var nameFieldFocused: Bool

    private var service: any DataSourceServiceProtocol { ServiceFactory.service(for: dataSource) }
    private var effectiveUnit: String { customUnit.isEmpty ? selectedUnit : customUnit }
    private var canSave: Bool { !queryName.isEmpty && !selectedTopic.isEmpty && !selectedFields.isEmpty }

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

                // Topic
                Section {
                    NavigationLink {
                        MQTTTopicPickerPage(
                            topics: topics,
                            isLoading: isLoadingTopics,
                            selection: $selectedTopic,
                            onSelect: { t in selectTopic(t) }
                        )
                    } label: {
                        summaryRow(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Topic",
                            value: selectedTopic.isEmpty ? nil : selectedTopic,
                            done: !selectedTopic.isEmpty
                        )
                    }
                }

                // Fields (only after topic)
                if !selectedTopic.isEmpty {
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

                        if isLoadingFields {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Subscribing to discover fields...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Collect Duration
                    Section {
                        NavigationLink {
                            MQTTCollectDurationPage(duration: $collectDuration)
                        } label: {
                            summaryRow(
                                icon: "clock",
                                title: "Collect Duration",
                                value: collectDuration.displayName,
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
                            MQTTPreviewPage(
                                topic: selectedTopic,
                                fields: Array(selectedFields),
                                duration: collectDuration,
                                service: service
                            )
                        } label: {
                            Label("Preview Live Data", systemImage: "play.circle")
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
            .navigationTitle(existingQuery != nil ? "Edit Query" : "New MQTT Query")
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
                loadTopics()
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

    private func selectTopic(_ t: String) {
        let changed = selectedTopic != t
        selectedTopic = t
        if changed {
            selectedFields = []
            availableFields = []
            discoverFields(topic: t)
        }
        if queryName.isEmpty { queryName = t.replacingOccurrences(of: "/", with: " ").replacingOccurrences(of: "#", with: "all") }
    }

    private func loadTopics() {
        isLoadingTopics = true
        Task {
            do {
                let result = try await service.fetchMeasurements()
                await MainActor.run { topics = result; isLoadingTopics = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoadingTopics = false }
            }
        }
    }

    private func discoverFields(topic: String) {
        isLoadingFields = true
        Task {
            do {
                let result = try await service.fetchFieldKeys(measurement: topic)
                await MainActor.run { availableFields = result; isLoadingFields = false }
            } catch {
                await MainActor.run {
                    availableFields = ["value"]
                    isLoadingFields = false
                }
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
        target.measurement = selectedTopic
        target.wrappedFields = Array(selectedFields)
        target.timeRange = collectDuration.asTimeRange.rawValue
        target.aggregateWindow = AggregateWindow.none.rawValue
        target.aggregateFunction = AggregateFunction.last.rawValue
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
        selectedTopic = q.wrappedMeasurement
        selectedFields = Set(q.wrappedFields)
        collectDuration = MQTTCollectDuration.from(timeRange: q.wrappedTimeRange)
        let u = q.wrappedUnit
        let presets = ["°C", "°F", "%", "hPa", "W", "kW", "kWh", "V", "A", "m/s", "km/h", "m", "km", "s", "min", "L"]
        if presets.contains(u) { selectedUnit = u } else if !u.isEmpty { customUnit = u }
        if !selectedTopic.isEmpty {
            discoverFields(topic: selectedTopic)
        }
    }
}

// MARK: - MQTT Collect Duration

enum MQTTCollectDuration: String, CaseIterable, Identifiable {
    case fiveSeconds = "5s"
    case tenSeconds = "10s"
    case fifteenSeconds = "15s"
    case twentySeconds = "20s"
    case thirtySeconds = "30s"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveSeconds: return "5 seconds"
        case .tenSeconds: return "10 seconds"
        case .fifteenSeconds: return "15 seconds"
        case .twentySeconds: return "20 seconds"
        case .thirtySeconds: return "30 seconds"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .fiveSeconds: return 5
        case .tenSeconds: return 10
        case .fifteenSeconds: return 15
        case .twentySeconds: return 20
        case .thirtySeconds: return 30
        }
    }

    var asTimeRange: TimeRange {
        switch self {
        case .fiveSeconds, .tenSeconds: return .oneHour
        case .fifteenSeconds: return .sixHours
        case .twentySeconds: return .twentyFourHours
        case .thirtySeconds: return .sevenDays
        }
    }

    static func from(timeRange: TimeRange) -> MQTTCollectDuration {
        switch timeRange {
        case .oneHour: return .tenSeconds
        case .sixHours: return .fifteenSeconds
        case .twentyFourHours: return .twentySeconds
        case .sevenDays, .thirtyDays: return .thirtySeconds
        }
    }
}

// MARK: - Topic Picker Page

struct MQTTTopicPickerPage: View {
    let topics: [String]
    let isLoading: Bool
    @Binding var selection: String
    let onSelect: (String) -> Void
    @State private var customTopic = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if isLoading {
                HStack { ProgressView(); Text("Loading...").padding(.leading, 8) }
            } else {
                Section("Configured Subscriptions") {
                    ForEach(topics, id: \.self) { topic in
                        Button {
                            onSelect(topic)
                            dismiss()
                        } label: {
                            HStack {
                                Text(topic).foregroundStyle(.primary)
                                Spacer()
                                if selection == topic {
                                    Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                Section("Custom Topic") {
                    HStack {
                        TextField("e.g. home/living/temperature", text: $customTopic)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Button("Use") {
                            guard !customTopic.isEmpty else { return }
                            onSelect(customTopic)
                            dismiss()
                        }
                        .disabled(customTopic.isEmpty)
                    }
                }
            }
        }
        .navigationTitle("Topic")
    }
}

// MARK: - Collect Duration Page

struct MQTTCollectDurationPage: View {
    @Binding var duration: MQTTCollectDuration

    var body: some View {
        Form {
            Section(footer: Text("How long to subscribe and collect messages when fetching data. Longer durations capture more data points but take longer to load.")) {
                Picker("Duration", selection: $duration) {
                    ForEach(MQTTCollectDuration.allCases) { d in
                        Text(d.displayName).tag(d)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Collect Duration")
    }
}

// MARK: - Preview Page

struct MQTTPreviewPage: View {
    let topic: String
    let fields: [String]
    let duration: MQTTCollectDuration
    let service: any DataSourceServiceProtocol

    @State private var result: QueryResult?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Configuration") {
                LabeledContent("Topic", value: topic)
                LabeledContent("Fields", value: fields.joined(separator: ", "))
                LabeledContent("Duration", value: duration.displayName)
            }

            Section {
                Button(action: runPreview) {
                    HStack {
                        Label("Collect Data", systemImage: "play.fill")
                        Spacer()
                        if isLoading { ProgressView() }
                    }
                }
                .disabled(isLoading)
            }

            if let result {
                Section("\(result.rows.count) data points") {
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
        let queryStr = MQTTQueryParser.build(topic: topic, fields: fields, rangeSeconds: duration.seconds)
        Task {
            do {
                let r = try await service.query(queryStr)
                await MainActor.run { result = r; isLoading = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
            }
        }
    }
}
