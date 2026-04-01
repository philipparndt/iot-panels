import SwiftUI

#if !os(watchOS)

// MARK: - Chart Explorer View

struct ChartExplorerView: View {
    @ObservedObject var panel: DashboardPanel
    @Environment(\.dismiss) private var dismiss

    @State private var state: ChartExplorerState

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
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(state.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
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
                        Text("Previous \(state.comparisonOffset.fluxValue)")
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
                .background(isActive ? Color.accentColor.opacity(0.2) : Color(uiColor: .tertiarySystemFill))
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
                            .background(Color(uiColor: .tertiarySystemFill))
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
                            .background(Color(uiColor: .tertiarySystemFill))
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
