import SwiftUI

struct DisplayStylePickerView: View {
    @Binding var selection: PanelDisplayStyle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(PanelDisplayStyle.grouped(), id: \.category) { group in
                Section(group.category.displayName) {
                    ForEach(group.styles) { s in
                        Button {
                            selection = s
                            dismiss()
                        } label: {
                            HStack {
                                Label(s.displayName, systemImage: s.icon)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selection == s {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Display Style")
        .inlineNavigationTitle()
    }
}
