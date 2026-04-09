import SwiftUI
#if os(macOS)
import AppKit
#endif

#if !os(watchOS)

// Local cross-platform tertiary fill color — lives here (not in a shared helper
// file) because ChartExplorerView.swift is also compiled into the widget
// extension target, which does not see the main-app-only helper files.
private extension Color {
    static var tertiaryFillCompat: Color {
        #if os(macOS)
        Color.secondary.opacity(0.12)
        #else
        Color(uiColor: .tertiarySystemFill)
        #endif
    }
}

// MARK: - Chart Explorer View

struct ChartExplorerView: View {
    @ObservedObject var panel: DashboardPanel
    @Environment(\.dismiss) private var dismiss

    @State private var state: ChartExplorerState
    @State private var exportCSVURL: URL?
    @State private var showingShareSheet = false
    @State private var isExporting = false

    init(panel: DashboardPanel) {
        self.panel = panel
        self._state = State(initialValue: ChartExplorerState(panel: panel))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chart area
                chartContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal)

                Divider()

                // Toolbar controls
                ExplorerToolbar(state: state)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            #if os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color(uiColor: .systemGroupedBackground))
            #endif
            .navigationTitle(state.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 8) {
                        Menu {
                            Button {
                                exportExplorer(format: "csv")
                            } label: {
                                Label("CSV", systemImage: "tablecells")
                            }
                            Button {
                                exportExplorer(format: "json")
                            } label: {
                                Label("JSON", systemImage: "curlybraces")
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .disabled(state.dataPoints.isEmpty)

                        if state.hasChanges {
                            Button {
                                state.resetAll()
                            } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                                    .font(.caption2.weight(.medium))
                            }
                        }
                        if state.isLoading {
                            ProgressView()
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportCSVURL {
                DataShareSheetView(items: [url])
            }
        }
        #elseif os(macOS)
        .onChange(of: showingShareSheet) { _, newValue in
            if newValue, let url = exportCSVURL {
                let panel = NSSavePanel()
                panel.nameFieldStringValue = url.lastPathComponent
                panel.canCreateDirectories = true
                panel.begin { response in
                    if response == .OK, let destination = panel.url {
                        try? FileManager.default.removeItem(at: destination)
                        try? FileManager.default.copyItem(at: url, to: destination)
                    }
                }
                showingShareSheet = false
            }
        }
        #endif
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Exporting...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .onAppear {
            state.loadData()
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if let errorMessage = state.errorMessage, state.dataPoints.isEmpty {
            VStack(spacing: 8) {
                Label(errorMessage, systemImage: "xmark.circle")
                    .foregroundStyle(.red)
                    .font(.callout)
                Button("Retry") {
                    state.loadData()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.dataPoints.isEmpty && !state.isLoading {
            VStack(spacing: 8) {
                Label("No data available", systemImage: "chart.xyaxis.line")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                PanelRenderer(
                    title: "",
                    style: state.displayStyle,
                    series: buildSeries(),
                    compact: false,
                    unit: state.unit,
                    styleConfig: state.styleConfig
                )

                // Comparison legend
                if state.comparisonOffset != .none && !state.comparisonDataPoints.isEmpty {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.accentColor.complementary())
                            .frame(width: 16, height: 2)
                            .overlay(
                                Rectangle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                    .foregroundStyle(Color.accentColor.complementary())
                            )
                        Text(state.comparisonOffset.legendLabel)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 2)
                }

                // Offset indicator
                if state.windowOffset != 0 {
                    Text("Viewing historical data")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            }
            .opacity(state.isLoading && !state.dataPoints.isEmpty ? 0.6 : 1)
        }
    }

    private func exportExplorer(format: String) {
        isExporting = true
        let name = state.title.isEmpty ? "export" : state.title
        let points = state.dataPoints
        let compPoints = state.comparisonDataPoints

        Task.detached(priority: .userInitiated) {
            let url: URL?
            if format == "json" {
                url = DataExporter.tempJSONFile(name: name, from: points, comparisonPoints: compPoints)
            } else {
                url = DataExporter.tempCSVFile(name: name, from: points, comparisonPoints: compPoints)
            }
            await MainActor.run {
                isExporting = false
                if let url {
                    exportCSVURL = url
                    showingShareSheet = true
                }
            }
        }
    }

    private func buildSeries() -> [ChartSeries] {
        let grouped = Dictionary(grouping: state.dataPoints, by: \.field)
        let colors: [Color] = [.accentColor, .blue, .green, .orange, .purple, .red]
        var result: [ChartSeries] = []

        for (i, key) in grouped.keys.sorted().enumerated() {
            let points = grouped[key] ?? []
            result.append(ChartSeries(
                id: key,
                label: key,
                color: colors[i % colors.count],
                dataPoints: points
            ))
        }

        if !state.comparisonDataPoints.isEmpty {
            let cmpGrouped = Dictionary(grouping: state.comparisonDataPoints, by: \.field)
            for (i, key) in cmpGrouped.keys.sorted().enumerated() {
                let points = cmpGrouped[key] ?? []
                result.append(ChartSeries(
                    id: "cmp_\(key)",
                    label: "cmp_\(key)",
                    color: colors[i % colors.count].complementary(),
                    dataPoints: points
                ))
            }
        }

        if result.count == 1 && state.comparisonDataPoints.isEmpty {
            return [ChartSeries(id: "default", label: result[0].label, color: .accentColor, dataPoints: result[0].dataPoints)]
        }

        return result
    }
}

// MARK: - Tag Menu Button

struct ExplorerTagMenu<Content: View>: View {
    let label: String
    let icon: String
    var isActive: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            Label(label, systemImage: icon)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.tertiaryFillCompat)
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Explorer Toolbar

struct ExplorerToolbar: View {
    @Bindable var state: ChartExplorerState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if !state.isMQTT {
                    // Step controls
                    Button { state.stepBackward() } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.tertiaryFillCompat)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if state.windowOffset != 0 {
                        Button { state.resetOffset() } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button { state.stepForward() } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.tertiaryFillCompat)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!state.canStepForward)

                    // Time range
                    ExplorerTagMenu(label: state.timeRange.displayName, icon: "clock") {
                        ForEach(TimeRange.allCases) { range in
                            Button {
                                state.timeRange = range
                                state.settingsChanged()
                            } label: {
                                if state.timeRange == range {
                                    Label(range.displayName, systemImage: "checkmark")
                                } else {
                                    Text(range.displayName)
                                }
                            }
                        }
                    }
                }

                // Aggregate window
                ExplorerTagMenu(label: state.aggregateWindow.displayName, icon: "ruler") {
                    ForEach(state.allowedWindows) { window in
                        Button {
                            state.aggregateWindow = window
                            state.settingsChanged()
                        } label: {
                            if state.aggregateWindow == window {
                                Label(window.displayName, systemImage: "checkmark")
                            } else {
                                Text(window.displayName)
                            }
                        }
                    }
                }

                // Aggregate function
                ExplorerTagMenu(label: state.aggregateFunction.displayName, icon: "function") {
                    ForEach(AggregateFunction.allCases) { fn in
                        Button {
                            state.aggregateFunction = fn
                            state.settingsChanged()
                        } label: {
                            if state.aggregateFunction == fn {
                                Label(fn.displayName, systemImage: "checkmark")
                            } else {
                                Text(fn.displayName)
                            }
                        }
                    }
                }

                // Comparison
                if !state.isMQTT {
                    ExplorerTagMenu(
                        label: state.comparisonOffset == .none ? "Compare" : state.comparisonOffset.displayName,
                        icon: "square.2.layers.3d.bottom.filled",
                        isActive: state.comparisonOffset != .none
                    ) {
                        ForEach(ComparisonOffset.allCases) { offset in
                            Button {
                                state.comparisonOffset = offset
                                state.settingsChanged()
                            } label: {
                                if state.comparisonOffset == offset {
                                    Label(offset.displayName, systemImage: "checkmark")
                                } else {
                                    Text(offset.displayName)
                                }
                            }
                        }
                    }
                }


            }
        }
    }
}

#endif
