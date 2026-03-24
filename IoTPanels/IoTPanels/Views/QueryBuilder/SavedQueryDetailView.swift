import SwiftUI

struct SavedQueryDetailView: View {
    let dataSource: DataSource
    @ObservedObject var savedQuery: SavedQuery

    @State private var result: QueryResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingEditor = false

    @Environment(\.managedObjectContext) private var viewContext

    private var service: InfluxDB2Service {
        InfluxDB2Service(dataSource: dataSource)
    }

    var body: some View {
        List {
            Section("Query") {
                Text(savedQuery.buildFluxQuery(bucket: dataSource.wrappedBucket))
                    .font(.system(.caption, design: .monospaced))
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

            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Running query...")
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
        .navigationTitle(savedQuery.wrappedName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: runQuery) {
                        Label("Run Query", systemImage: "play.fill")
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
            QueryBuilderView(dataSource: dataSource, existingQuery: savedQuery)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear { runQuery() }
    }

    private func runQuery() {
        isLoading = true
        errorMessage = nil
        let flux = savedQuery.buildFluxQuery(bucket: dataSource.wrappedBucket)
        Task {
            do {
                let queryResult = try await service.query(flux)
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
