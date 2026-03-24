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

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
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
            }
        }
    }

    private var existingGroups: [String] {
        let allItems = design.sortedItems
        let tags = allItems.compactMap { $0.groupTag }.filter { !$0.isEmpty }
        return Array(Set(tags)).sorted()
    }
}
