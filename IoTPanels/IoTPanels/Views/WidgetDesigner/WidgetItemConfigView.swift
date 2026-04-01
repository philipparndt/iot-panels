import SwiftUI

struct WidgetItemConfigView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var item: WidgetDesignItem
    let design: WidgetDesign

    @State private var title = ""
    @State private var style: PanelDisplayStyle = .chart
    @State private var selectedColor = ""
    @State private var groupTag = ""
    @State private var styleConfig = StyleConfig.default
    @State private var gaugeMinText = ""
    @State private var gaugeMaxText = ""
    @State private var timeRange: TimeRange = .twoHours
    @State private var aggregateWindow: AggregateWindow = .fiveMinutes
    @State private var aggregateFunction: AggregateFunction = .mean
    @State private var comparisonOffset: ComparisonOffset = .none
    @State private var bandOpacityText = ""

    // Original values for cancel/restore
    @State private var originalTitle = ""
    @State private var originalStyle: PanelDisplayStyle = .chart
    @State private var originalColor = ""
    @State private var originalGroupTag = ""
    @State private var originalStyleConfig = StyleConfig.default
    @State private var originalTimeRange: TimeRange = .twoHours
    @State private var originalAggregateWindow: AggregateWindow = .fiveMinutes
    @State private var originalAggregateFunction: AggregateFunction = .mean
    @State private var originalComparisonOffset: ComparisonOffset = .none

    var body: some View {
        NavigationStack {
            Form {
                labelSection
                styleSection
                dataSection
                comparisonSection
                styleConfigSections
                colorSection
                groupSection
            }
            .navigationTitle("Configure Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        item.title = originalTitle
                        item.wrappedDisplayStyle = originalStyle
                        item.colorHex = originalColor
                        item.groupTag = originalGroupTag.isEmpty ? nil : originalGroupTag
                        item.wrappedStyleConfig = originalStyleConfig
                        item.effectiveTimeRange = originalTimeRange
                        item.effectiveAggregateWindow = originalAggregateWindow
                        item.effectiveAggregateFunction = originalAggregateFunction
                        item.wrappedComparisonOffset = originalComparisonOffset
                        item.modifiedAt = Date()
                        try? viewContext.save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.title = title
                        item.wrappedDisplayStyle = style
                        item.colorHex = selectedColor
                        item.groupTag = groupTag.isEmpty ? nil : groupTag
                        item.wrappedStyleConfig = styleConfig
                        item.effectiveTimeRange = timeRange
                        item.effectiveAggregateWindow = aggregateWindow
                        item.effectiveAggregateFunction = aggregateFunction
                        item.wrappedComparisonOffset = comparisonOffset
                        item.modifiedAt = Date()
                        design.modifiedAt = Date()
                        try? viewContext.save()
                        WidgetHelper.reloadWidgets()
                        dismiss()
                    }
                }
            }
            .onAppear {
                title = item.wrappedTitle
                style = item.wrappedDisplayStyle
                selectedColor = item.wrappedColorHex
                groupTag = item.groupTag ?? ""
                styleConfig = item.wrappedStyleConfig
                if let min = styleConfig.gaugeMin { gaugeMinText = String(format: "%.1f", min) }
                if let max = styleConfig.gaugeMax { gaugeMaxText = String(format: "%.1f", max) }
                timeRange = item.effectiveTimeRange
                aggregateWindow = item.effectiveAggregateWindow
                aggregateFunction = item.effectiveAggregateFunction
                comparisonOffset = item.wrappedComparisonOffset
                if let opacity = styleConfig.bandOpacity { bandOpacityText = String(format: "%.1f", opacity) }

                // Save originals for cancel/restore
                originalTitle = item.wrappedTitle
                originalStyle = item.wrappedDisplayStyle
                originalColor = item.wrappedColorHex
                originalGroupTag = item.groupTag ?? ""
                originalStyleConfig = item.wrappedStyleConfig
                originalTimeRange = item.effectiveTimeRange
                originalAggregateWindow = item.effectiveAggregateWindow
                originalAggregateFunction = item.effectiveAggregateFunction
                originalComparisonOffset = item.wrappedComparisonOffset
            }
            .onChange(of: style) {
                item.wrappedDisplayStyle = style
                if style == .bandChart && aggregateWindow == .none {
                    aggregateWindow = timeRange.minimumWindow
                }
            }
            .onChange(of: styleConfig) {
                item.wrappedStyleConfig = styleConfig
            }
            .onChange(of: timeRange) {
                item.effectiveTimeRange = timeRange
            }
            .onChange(of: aggregateWindow) {
                item.effectiveAggregateWindow = aggregateWindow
            }
            .onChange(of: aggregateFunction) {
                item.effectiveAggregateFunction = aggregateFunction
            }
            .onChange(of: comparisonOffset) {
                item.wrappedComparisonOffset = comparisonOffset
            }
        }
    }

    // MARK: - Extracted Sections

    private var labelSection: some View {
        Section {
            TextField("e.g. in, out, temp", text: $title)
        } header: {
            Text("Legend Label")
        } footer: {
            Text("Short name shown in the chart legend. Keep it brief for small widgets.")
        }
    }

    private var styleSection: some View {
        Section("Display Style") {
            ForEach(PanelDisplayStyle.allCases) { s in
                Button {
                    style = s
                } label: {
                    HStack {
                        Label(s.displayName, systemImage: s.icon)
                            .foregroundStyle(.primary)
                        Spacer()
                        if style == s {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Picker("Time Range", selection: $timeRange) {
                ForEach(TimeRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .onChange(of: timeRange) {
                let allowed = timeRange.allowedWindows
                if !allowed.contains(aggregateWindow) {
                    aggregateWindow = timeRange.minimumWindow
                }
            }

            Picker("Aggregation", selection: $aggregateWindow) {
                ForEach(timeRange.allowedWindows) { window in
                    Text(window.displayName).tag(window)
                }
            }

            Picker("Function", selection: $aggregateFunction) {
                ForEach(AggregateFunction.allCases) { fn in
                    Text(fn.displayName).tag(fn)
                }
            }
        }
    }

    @ViewBuilder
    private var comparisonSection: some View {
        if style.isLineBased {
            Section {
                Picker("Comparison Period", selection: $comparisonOffset) {
                    ForEach(ComparisonOffset.allCases) { offset in
                        Text(offset.displayName).tag(offset)
                    }
                }
                if comparisonOffset != .none {
                    Text(comparisonOffset.pickerDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Compare With")
            }
        }
    }

    @ViewBuilder
    private var styleConfigSections: some View {
        if style == .gauge {
            gaugeConfigSections
        }
        if style == .calendarHeatmap || style == .calendarHeatmapDense {
            heatmapColorSection
        }
        if style == .bandChart {
            bandConfigSection
        }
        if style != .gauge {
            ThresholdEditorView(thresholds: Binding(
                get: { styleConfig.thresholds ?? [] },
                set: { styleConfig.thresholds = $0.isEmpty ? nil : $0 }
            ))
        }
    }

    private var gaugeConfigSections: some View {
        Group {
            Section {
                HStack {
                    Text("Min").frame(width: 40)
                    TextField("Auto", text: $gaugeMinText)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .onChange(of: gaugeMinText) { styleConfig.gaugeMin = Double(gaugeMinText) }
                }
                HStack {
                    Text("Max").frame(width: 40)
                    TextField("Auto", text: $gaugeMaxText)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .onChange(of: gaugeMaxText) { styleConfig.gaugeMax = Double(gaugeMaxText) }
                }
            } header: {
                Text("Gauge Range")
            } footer: {
                Text("Leave empty for auto range based on data.")
            }

            Section("Gauge Color Scheme") {
                ForEach(GaugeColorScheme.allCases) { scheme in
                    Button {
                        styleConfig.gaugeColorScheme = scheme.rawValue
                    } label: {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(colors: scheme.colors, startPoint: .leading, endPoint: .trailing))
                                .frame(width: 40, height: 10)
                            Text(scheme.displayName).foregroundStyle(.primary)
                            Spacer()
                            if styleConfig.resolvedGaugeColorScheme == scheme {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
    }

    private var heatmapColorSection: some View {
        Section("Heatmap Color") {
            ForEach(HeatmapColor.allCases) { color in
                Button {
                    styleConfig.heatmapColor = color.rawValue
                } label: {
                    HStack(spacing: 8) {
                        HeatmapSwatchView(color: color)
                        Text(color.displayName).foregroundStyle(.primary)
                        Spacer()
                        if styleConfig.resolvedHeatmapColor == color {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
    }

    private var bandConfigSection: some View {
        Section {
            HStack {
                Text("Opacity").frame(width: 60)
                TextField("0.2", text: $bandOpacityText)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .onChange(of: bandOpacityText) { styleConfig.bandOpacity = Double(bandOpacityText) }
            }
        } header: {
            Text("Band Chart")
        }
    }

    private var colorSection: some View {
        Section("Color") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                ForEach(SeriesColors.palette, id: \.self) { hex in
                    Group {
                        if hex == SeriesColors.adaptivePrimary {
                            // Split circle: white/black to indicate adaptive
                            ZStack {
                                Circle().fill(Color.white)
                                Circle().fill(Color.black)
                                    .mask(
                                        Rectangle().offset(x: 15)
                                    )
                                Circle().strokeBorder(Color.gray.opacity(0.4), lineWidth: 0.5)
                            }
                        } else {
                            Circle().fill(Color(hex: hex))
                        }
                    }
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .strokeBorder(.primary, lineWidth: selectedColor == hex ? 2 : 0)
                            .padding(-2)
                    )
                    .onTapGesture { selectedColor = hex }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var groupSection: some View {
        Section {
            TextField("Group name (e.g. A)", text: $groupTag)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            if !existingGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(existingGroups, id: \.self) { tag in
                            Button(tag) { groupTag = tag }
                                .buttonStyle(.bordered)
                                .tint(groupTag == tag ? .accentColor : .secondary)
                        }
                        if !groupTag.isEmpty {
                            Button("Clear") { groupTag = "" }
                                .buttonStyle(.bordered)
                                .tint(.red)
                        }
                    }
                }
            }
        } header: {
            Text("Chart Group")
        } footer: {
            Text("Items with the same group name will be rendered as multiple curves on one chart.")
        }
    }

    private var existingGroups: [String] {
        let allItems = design.sortedItems
        let tags = allItems.compactMap { $0.groupTag }.filter { !$0.isEmpty }
        return Array(Set(tags)).sorted()
    }
}
