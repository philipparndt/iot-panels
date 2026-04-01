import SwiftUI

/// Reusable editor for threshold color rules.
struct ThresholdEditorView: View {
    @Binding var thresholds: [ThresholdRule]

    var body: some View {
        Section {
            ForEach(Array(thresholds.enumerated()), id: \.offset) { index, rule in
                thresholdRow(index: index, rule: rule)
            }
            .onDelete { offsets in
                thresholds.remove(atOffsets: offsets)
            }

            Button {
                let nextValue = (thresholds.last?.value ?? 0) + 10
                thresholds.append(ThresholdRule(value: nextValue, colorHex: "#2ECC71"))
                thresholds.sort { $0.value < $1.value }
            } label: {
                Label("Add Threshold", systemImage: "plus.circle")
            }
        } header: {
            Text("Color Thresholds")
        } footer: {
            Text("Color changes when value reaches the threshold. Values below the first threshold use the base color.")
        }
    }

    private func thresholdRow(index: Int, rule: ThresholdRule) -> some View {
        HStack(spacing: 10) {
            TextField("Value", value: Binding(
                get: { thresholds[index].value },
                set: { thresholds[index].value = $0 }
            ), format: .number)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .frame(width: 80)

            Text("→")
                .foregroundStyle(.secondary)

            colorPicker(index: index)

            Spacer()
        }
    }

    private func colorPicker(index: Int) -> some View {
        let presetColors = SeriesColors.palette

        return Menu {
            ForEach(presetColors, id: \.self) { hex in
                Button {
                    thresholds[index].colorHex = hex
                } label: {
                    Label(colorLabel(for: hex), systemImage: thresholds[index].colorHex == hex ? "checkmark.circle.fill" : "circle.fill")
                }
            }
        } label: {
            Circle()
                .fill(Color(hex: thresholds[index].colorHex))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private func colorLabel(for hex: String) -> String {
        switch hex {
        case "#4A90D9": return "Blue"
        case "#E74C3C": return "Red"
        case "#2ECC71": return "Green"
        case "#F39C12": return "Orange"
        case "#9B59B6": return "Purple"
        case "#1ABC9C": return "Teal"
        case "#E67E22": return "Dark Orange"
        case "#3498DB": return "Light Blue"
        case SeriesColors.adaptivePrimary: return "Auto"
        default: return hex
        }
    }
}
