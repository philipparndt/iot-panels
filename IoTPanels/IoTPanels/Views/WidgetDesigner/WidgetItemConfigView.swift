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
    @State private var showSparkline = false
    @State private var sparklineMinText = ""
    @State private var sparklineMaxText = ""

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
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("Configure Item")
            .inlineNavigationTitle()
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
                showSparkline = styleConfig.showSparkline ?? false
                if let min = styleConfig.sparklineMin { sparklineMinText = String(format: "%.1f", min) }
                if let max = styleConfig.sparklineMax { sparklineMaxText = String(format: "%.1f", max) }

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
            NavigationLink {
                DisplayStylePickerView(selection: $style)
            } label: {
                HStack {
                    Text("Style")
                    Spacer()
                    Label(style.displayName, systemImage: style.icon)
                        .foregroundStyle(.secondary)
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
        if style.supportsComparison {
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
        if style.supportsGaugeConfig {
            gaugeConfigSections
        }
        if style.supportsHeatmapColor {
            heatmapColorSection
        }
        if style.supportsBandConfig {
            bandConfigSection
        }
        if style.supportsSparkline {
            sparklineSection
        }
        if style.supportsStateConfig {
            stateAliasSection
            stateColorSection
        }
        if style.supportsThresholds {
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

    private var sparklineSection: some View {
        Section {
            Toggle("Show Sparkline", isOn: $showSparkline)
                .onChange(of: showSparkline) {
                    styleConfig.showSparkline = showSparkline ? true : nil
                }
            if showSparkline {
                HStack {
                    Text("Min").frame(width: 40)
                    TextField("Auto", text: $sparklineMinText)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .onChange(of: sparklineMinText) { styleConfig.sparklineMin = Double(sparklineMinText) }
                }
                HStack {
                    Text("Max").frame(width: 40)
                    TextField("Auto", text: $sparklineMaxText)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .onChange(of: sparklineMaxText) { styleConfig.sparklineMax = Double(sparklineMaxText) }
                }
            }
        } header: {
            Text("Sparkline")
        } footer: {
            Text("Shows a subtle background sparkline. Leave range empty for auto.")
        }
    }

    @State private var newStateName = ""
    @State private var newStateColor = "#007AFF"
    @State private var newAliasValue = ""
    @State private var newAliasLabel = ""
    @FocusState private var newAliasValueFocused: Bool

    private var sortedAliasIndices: [(offset: Int, alias: StateAlias)] {
        guard let aliases = styleConfig.stateAliases else { return [] }
        return aliases.enumerated()
            .sorted { $0.element.value < $1.element.value }
            .map { (offset: $0.offset, alias: $0.element) }
    }

    private var sortedAliases: [StateAlias] {
        (styleConfig.stateAliases ?? []).sorted { $0.value < $1.value }
    }

    private var stateAliasSection: some View {
        Section {
            ForEach(sortedAliasIndices, id: \.alias.value) { item in
                HStack {
                    Text("≥")
                        .foregroundStyle(.secondary)
                    TextField("0", text: Binding(
                        get: { String(format: "%.0f", styleConfig.stateAliases?[item.offset].value ?? 0) },
                        set: { if let val = Double($0) { styleConfig.stateAliases?[item.offset].value = val } }
                    ))
                    .keyboardType(.decimalPad)
                    .frame(width: 50)
                    TextField("Label", text: Binding(
                        get: { styleConfig.stateAliases?[item.offset].label ?? "" },
                        set: { styleConfig.stateAliases?[item.offset].label = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
            }
            .onDelete { offsets in
                let toRemove = offsets.map { sortedAliasIndices[$0].offset }
                for index in toRemove.sorted().reversed() {
                    styleConfig.stateAliases?.remove(at: index)
                }
                if styleConfig.stateAliases?.isEmpty == true { styleConfig.stateAliases = nil }
            }

            HStack {
                Text("≥")
                    .foregroundStyle(.secondary)
                TextField("0", text: $newAliasValue)
                    .keyboardType(.decimalPad)
                    .frame(width: 50)
                    .focused($newAliasValueFocused)
                TextField("Label (e.g. Calm)", text: $newAliasLabel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    guard let val = Double(newAliasValue), !newAliasLabel.isEmpty else { return }
                    if styleConfig.stateAliases == nil { styleConfig.stateAliases = [] }
                    styleConfig.stateAliases?.removeAll { $0.value == val }
                    styleConfig.stateAliases?.append(StateAlias(value: val, label: newAliasLabel))
                    newAliasValue = ""
                    newAliasLabel = ""
                    newAliasValueFocused = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(Double(newAliasValue) == nil || newAliasLabel.isEmpty)
            }
        } header: {
            Text("Value Aliases")
        } footer: {
            Text("Map numeric value ranges to state labels. \"≥ 20 Windy\" means values from 20 upward show as \"Windy\". Swipe to delete.")
        }
    }

    private var stateColorSection: some View {
        Section {
            ForEach(Array((styleConfig.stateColors ?? []).enumerated()), id: \.element.state) { index, entry in
                HStack {
                    stateColorPicker(currentHex: entry.colorHex) { hex in
                        styleConfig.stateColors?[index].colorHex = hex
                    }
                    Text(entry.state)
                        .foregroundStyle(.primary)
                }
            }
            .onDelete { offsets in
                let entries = styleConfig.stateColors ?? []
                let toRemove = offsets.map { entries[$0].state }
                styleConfig.stateColors?.removeAll { toRemove.contains($0.state) }
                if styleConfig.stateColors?.isEmpty == true { styleConfig.stateColors = nil }
            }

            // Quick-add from alias labels
            let existingStates = Set((styleConfig.stateColors ?? []).map(\.state))
            let suggestions = sortedAliases.map(\.label).filter { !existingStates.contains($0) }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { label in
                            Button(label) {
                                if styleConfig.stateColors == nil { styleConfig.stateColors = [] }
                                styleConfig.stateColors?.append(StateColorEntry(state: label, colorHex: newStateColor))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            HStack {
                stateColorPicker(currentHex: newStateColor) { hex in
                    newStateColor = hex
                }
                TextField("State name", text: $newStateName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    guard !newStateName.isEmpty else { return }
                    if styleConfig.stateColors == nil { styleConfig.stateColors = [] }
                    styleConfig.stateColors?.removeAll { $0.state == newStateName }
                    styleConfig.stateColors?.append(StateColorEntry(state: newStateName, colorHex: newStateColor))
                    newStateName = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newStateName.isEmpty)
            }
        } header: {
            Text("State Colors")
        } footer: {
            Text("Map state values to colors. Unmapped states use automatic colors. Swipe to delete.")
        }
    }

    private func stateColorPicker(currentHex: String, onSelect: @escaping (String) -> Void) -> some View {
        let binding = Binding<String>(
            get: { currentHex },
            set: { onSelect($0) }
        )
        return Picker("", selection: binding) {
            ForEach(StateColorResolver.palette, id: \.hex) { entry in
                Label(entry.name, systemImage: "circle.fill")
                    .tint(Color(hex: entry.hex))
                    .foregroundStyle(Color(hex: entry.hex))
                    .tag(entry.hex)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(Color(hex: currentHex))
        .fixedSize()
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
