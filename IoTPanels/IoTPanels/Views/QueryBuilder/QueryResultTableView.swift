import SwiftUI

struct QueryResultTableView: View {
    let result: QueryResult

    private let hiddenColumns: Set<String> = ["", "result", "table"]

    private var visibleColumns: [QueryResult.Column] {
        result.columns.filter { !hiddenColumns.contains($0.name) }
    }

    var body: some View {
        if result.rows.isEmpty {
            Text("No data")
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        ForEach(Array(visibleColumns.enumerated()), id: \.offset) { _, col in
                            Text(col.name)
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.bold)
                                .frame(minWidth: 100, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }
                    }
                    .background(Color.secondary.opacity(0.15))

                    Divider()

                    // Rows
                    ForEach(Array(result.rows.prefix(100).enumerated()), id: \.offset) { rowIndex, row in
                        HStack(spacing: 0) {
                            ForEach(Array(visibleColumns.enumerated()), id: \.offset) { _, col in
                                Text(formatValue(row.values[col.name] ?? ""))
                                    .font(.system(.caption2, design: .monospaced))
                                    .frame(minWidth: 100, alignment: .leading)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                            }
                        }
                        .background(rowIndex % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
                    }
                }
            }
        }
    }

    private func formatValue(_ value: String) -> String {
        // Shorten ISO timestamps for readability
        if value.contains("T") && value.contains("Z") {
            return value
                .replacingOccurrences(of: "T", with: " ")
                .replacingOccurrences(of: "Z", with: "")
        }
        return value
    }
}
