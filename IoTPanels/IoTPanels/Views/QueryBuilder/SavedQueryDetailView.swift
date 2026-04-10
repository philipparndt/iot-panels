import SwiftUI

struct SavedQueryDetailView: View {
    let dataSource: DataSource
    @ObservedObject var savedQuery: SavedQuery

    @State private var result: QueryResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingEditor = false

    @Environment(\.managedObjectContext) private var viewContext

    private var service: any DataSourceServiceProtocol {
        ServiceFactory.service(for: dataSource)
    }

    private var isMQTT: Bool {
        dataSource.wrappedBackendType == .mqtt
    }

    var body: some View {
        List {
            if isMQTT {
                Section("MQTT Query") {
                    LabeledContent("Topic", value: savedQuery.wrappedMeasurement)
                    LabeledContent("Fields", value: savedQuery.wrappedFields.joined(separator: ", "))
                    if !savedQuery.wrappedUnit.isEmpty {
                        LabeledContent("Unit", value: savedQuery.wrappedUnit)
                    }
                }
            } else if savedQuery.wrappedIsRawQuery {
                Section("Manual Query") {
                    Text(savedQuery.wrappedRawQuery)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                if !savedQuery.wrappedUnit.isEmpty {
                    Section("Parameters") {
                        LabeledContent("Unit", value: savedQuery.wrappedUnit)
                    }
                }
            } else {
                Section("Query") {
                    Text(savedQuery.buildQuery(for: dataSource))
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section("Parameters") {
                    LabeledContent("Measurement", value: savedQuery.wrappedMeasurement)
                    LabeledContent("Fields", value: savedQuery.wrappedFields.joined(separator: ", "))
                    LabeledContent("Time Range", value: savedQuery.wrappedTimeRange.displayName)
                    if savedQuery.wrappedAggregateWindow != .none {
                        LabeledContent("Aggregation", value: "\(savedQuery.wrappedAggregateFunction.displayName) / \(savedQuery.wrappedAggregateWindow.displayName)")
                    }
                    if !savedQuery.wrappedUnit.isEmpty {
                        LabeledContent("Unit", value: savedQuery.wrappedUnit)
                    }

                    let tagFilters = savedQuery.wrappedTagFilters
                    if !tagFilters.isEmpty {
                        ForEach(Array(tagFilters.keys.sorted().enumerated()), id: \.element) { _, key in
                            LabeledContent(key, value: tagFilters[key]?.joined(separator: ", ") ?? "")
                        }
                    }
                }
            }

            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text(isMQTT ? "Collecting messages..." : "Running query...")
                            .padding(.leading, 8)
                    }
                }
            } else if let result {
                Section("Results (\(result.rows.count) rows)") {
                    QueryResultTableView(result: result)
                        .frame(minHeight: 300)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(savedQuery.wrappedName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: runQuery) {
                        Label(isMQTT ? "Collect Data" : "Run Query", systemImage: "play.fill")
                    }
                    Button(action: { showingEditor = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor, onDismiss: runQuery) {
            queryEditorSheet
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear { runQuery() }
    }

    @ViewBuilder
    private var queryEditorSheet: some View {
        if isMQTT {
            MQTTQueryBuilderView(dataSource: dataSource, existingQuery: savedQuery)
        } else if savedQuery.wrappedIsRawQuery {
            ManualQueryEditorView(dataSource: dataSource, existingQuery: savedQuery)
        } else {
            QueryBuilderView(dataSource: dataSource, existingQuery: savedQuery)
        }
    }

    private func runQuery() {
        isLoading = true
        errorMessage = nil
        let queryStr = savedQuery.buildQuery(for: dataSource)
        Task {
            do {
                let queryResult = try await service.query(queryStr)
                await MainActor.run {
                    result = queryResult
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
