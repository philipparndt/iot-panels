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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. in, out, temp", text: $title)
                } header: {
                    Text("Legend Label")
                } footer: {
                    Text("Short name shown in the chart legend. Keep it brief for small widgets.")
                }

                Section("Display Style") {
                    ForEach([PanelDisplayStyle.chart, .singleValue, .gauge], id: \.self) { s in
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

                if style == .gauge {
                    Section {
                        HStack {
                            Text("Min")
                                .frame(width: 40)
                            TextField("Auto", text: $gaugeMinText)
                                .keyboardType(.decimalPad)
                                .textInputAutocapitalization(.never)
                                .onChange(of: gaugeMinText) {
                                    styleConfig.gaugeMin = Double(gaugeMinText)
                                }
                        }

                        HStack {
                            Text("Max")
                                .frame(width: 40)
                            TextField("Auto", text: $gaugeMaxText)
                                .keyboardType(.decimalPad)
                                .textInputAutocapitalization(.never)
                                .onChange(of: gaugeMaxText) {
                                    styleConfig.gaugeMax = Double(gaugeMaxText)
                                }
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
                                    // Color preview bar
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(colors: scheme.colors, startPoint: .leading, endPoint: .trailing))
                                        .frame(width: 40, height: 10)

                                    Text(scheme.displayName)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if styleConfig.resolvedGaugeColorScheme == scheme {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(SeriesColors.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
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

                Section {
                    TextField("Group name (e.g. A)", text: $groupTag)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    if !existingGroups.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(existingGroups, id: \.self) { tag in
                                    Button(tag) {
                                        groupTag = tag
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(groupTag == tag ? .accentColor : .secondary)
                                }

                                if !groupTag.isEmpty {
                                    Button("Clear") {
                                        groupTag = ""
                                    }
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
            .navigationTitle("Configure Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.title = title
                        item.wrappedDisplayStyle = style
                        item.colorHex = selectedColor
                        item.groupTag = groupTag.isEmpty ? nil : groupTag
                        item.wrappedStyleConfig = styleConfig
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
            }
        }
    }

    private var existingGroups: [String] {
        let allItems = design.sortedItems
        let tags = allItems.compactMap { $0.groupTag }.filter { !$0.isEmpty }
        return Array(Set(tags)).sorted()
    }
}
